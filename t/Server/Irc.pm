package t::Server::Irc;
use Mojo::Base 'Mojo::EventEmitter';

use Carp 'confess';
use Convos::Core::Connection::Irc;
use Mojo::Loader;

has auto_connect     => 1;
has connection_class => 'Convos::Core::Connection::Irc';

has url => sub {
  my $port = Mojo::IOLoop::Server->generate_port;
  my $url  = Mojo::URL->new->host('127.0.0.1')->port($port)->scheme('irc');
  $url->query->param(tls => 0);
  return $url;
};

sub client {
  my $self = shift;
  return $self->{client} unless @_;
  $self->{client} = shift;
  push @{$self->{queue}}, [\&_handle_client_connect, $self->{client}] if $self->auto_connect;
  return $self;
}

sub client_event_ok {
  my ($self, $event, $cb) = @_;
  push @{$self->{queue}}, [\&_handle_client_event_item, $self->client, $event, $cb];
  $self->_dequeue unless $self->{outstanding_events}++;
  return $self;
}

sub close_connections {
  my $self = shift;

  my $connections = $self->{connections} || {};
  for my $id (keys %$connections) {
    $connections->{$id}{stream}->close;
    delete $connections->{$id};
  }

  return $self;
}

sub n_connections {
  return int keys %{shift->{connections} || {}};
}

sub process_ok {
  my ($self, $desc) = @_;
  my $tid = Mojo::IOLoop->timer(5 => sub { $self->_handle_process_timeout($desc) });

  my $run = sub {
    Mojo::IOLoop->one_tick while $self->{outstanding_events};
    Mojo::IOLoop->remove($tid);
  };

  return $self->_test(subtest => $desc, $run) if $desc;
  return $self->tap($run);
}

sub processed_ok {
  return $_[0]->_test(ok => !$_[0]->{outstanding_events}, $_[1] || 'processed');
}

sub server_event_ok {
  my ($self, $event, $cb) = @_;
  push @{$self->{queue}}, [\&_handle_server_event_item, $self->client, $event, $cb];
  $self->_dequeue unless $self->{outstanding_events}++;
  return $self;
}

sub server_write_ok {
  my ($self, $buf) = @_;
  $buf = $self->_data_section(@$buf) if ref $buf;
  push @{$self->{queue}}, [\&_handle_server_write_item, $self->client, $buf];
  $self->_dequeue unless $self->{outstanding_events};
  return $self;
}

sub start {
  my $self = shift;

  my $url        = $self->url;
  my %conn_attrs = (name => 'server', protocol => 'irc', url => $url);
  $conn_attrs{user} = Convos::Core::User->new(email => 'server@test');

  Mojo::IOLoop->server(
    {address => $url->host, port => $url->port},
    sub {
      my ($ioloop, $stream) = @_;
      my $s_conn = $self->connection_class->new(%conn_attrs, stream => $stream, stream_id => rand);
      $self->{connections}{$stream} = $s_conn;
      $stream->timeout(0);
      $stream->on(close => sub { delete $self->{connections}{$_[0]} });
      $stream->on(read  => sub { $s_conn->_stream_on_read(@_) });
      $self->emit(connection => $s_conn);
      $s_conn->write($self->_data_section('start.irc'));
    }
  );

  return $self->tap('_patch_connection_class');
}

sub _data_section {
  my ($self, $name) = (shift, pop);
  return Mojo::Loader::data_section($_[0], $name) if $_[0];

  for my $pkg ('main', __PACKAGE__) {
    my $data = Mojo::Loader::data_section($pkg);
    return $data->{$name} if defined $data->{$name};
  }

  Carp::confess("Couldn't find $name in __DATA__");
}

sub _dequeue {
  my $self = shift;
  my $item = shift @{$self->{queue}} or return $self;
  my $cb   = shift @$item;
  $self->$cb(@$item);
  return $self;
}

sub _desc {
  my ($prefix, $buf) = @_;
  return $prefix unless $buf;
  my $desc = substr $buf, 0, 30;
  $desc =~ s![\r\n]+! !g;
  $desc .= '...' unless length $desc == length $buf;
  return "$prefix $desc";
}

sub _find_server_conn {
  my ($self, $c_conn) = @_;
  return undef unless my $port = $c_conn->{stream} && $c_conn->{stream}->handle->sockport;

  my $connections = $self->{connections} || {};
  for my $conn (values %$connections) {
    return $conn if $conn->{stream}->handle->peerport == $port;
  }

  return undef;
}

sub _handle_client_connect {
  my ($self, $c_conn) = @_;

  unless ($c_conn->state eq 'connected') {
    $c_conn->url->host($self->url->host);
    $c_conn->url->port($self->url->port);
    $c_conn->url->query->param($_ => $self->url->query->param($_)) for @{$self->url->query->names};
    $c_conn->connect_p;
  }

  $self->_dequeue;
}

sub _handle_client_event_item {
  my ($self, $c_conn, $event, $cb) = @_;

  $c_conn->once(
    $event => sub {
      my ($conn, @event) = @_;
      $self->{outstanding_events}--;
      $self->_test(ok => 1, "client $event")->_dequeue;
      $conn->$cb(@event) if $cb;
    }
  );
}

sub _handle_process_timeout {
  my ($self, $desc) = @_;
  $self->{outstanding_events} = 0;
  $self->{queue}              = [];
  return Test::More::ok(0, $desc) if $desc;
  confess 'Timeout!';
}

sub _handle_server_event_item {
  my ($self, $c_conn, $event, $cb) = @_;

  $self->once(
    $event => sub {
      my ($self, $s_conn, @event) = @_;
      $self->{outstanding_events}--;
      $self->_test(ok => 1, _desc("server $event"))->_dequeue;
      $s_conn->$cb(@event) if $cb;
    }
  );
}

sub _handle_server_write_item {
  my ($self, $c_conn, $buf) = @_;
  return $self->_test(ok => 0, 'server write')
    unless my $s_conn = $self->_find_server_conn($c_conn);
  return $s_conn->write($buf, sub { $self->_dequeue });
}

sub _test {
  my ($self, $name, @args) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 2;
  Test::More->can($name)->(@args);
  return $self;
}

sub _patch_connection_class {
  my $self = shift;

  Mojo::Util::monkey_patch(
    $self->connection_class => can => sub {
      my ($conn, $method) = @_;
      return shift->SUPER::can(@_)
        unless ref $conn and $conn->name eq 'server' && $method =~ m!^_\w+_event_!;
      return sub { $self->emit($method => $conn, pop) };
    }
  );

  Mojo::Util::monkey_patch($self->connection_class => write => sub { shift->_write(@_) })
    unless $self->connection_class->can('write');
}

1;

__DATA__
@@ join-convos.irc
:Superman!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman #convos :some cool topic
:hybrid8.debian.local 333 Superman #convos superman!superman@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman = #convos :Superman @batman
:hybrid8.debian.local 366 Superman #convos :End of /NAMES list.
@@ identify.irc
:NickServ!clark.kent\@i.love.debian.org PRIVMSG #superman :You are now identified for batman
@@ ison.irc
:hybrid8.debian.local 303 test21362 :private_ryan
@@ welcome.irc
:hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
@@ start.irc
:hybrid8.local NOTICE AUTH :*** Looking up your hostname...
:hybrid8.local NOTICE AUTH :*** Checking Ident
:hybrid8.local NOTICE AUTH :*** Found your hostname
:hybrid8.local NOTICE AUTH :*** No Ident response
