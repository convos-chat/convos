package Convos::Controller::Connection;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'ce';

sub create {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $url  = Mojo::URL->new($args->{url});
  my $name = $args->{name} || $self->_pretty_connection_name($url->host);
  my $connection;

  if (!$name) {
    return $self->$cb(ce 'URL need a valid host.', '/url', 400);
  }
  if ($user->get_connection({protocol => $url->scheme, name => $name})) {
    return $self->$cb(ce 'Connection already exists.', '/', 400);
  }

  eval {
    $connection = $user->connection({protocol => $url->scheme, name => $name});
    $connection->url->parse($url);
    $self->delay(
      sub { $connection->save(shift->begin) },
      sub {
        my ($delay, $err) = @_;
        die $err if $err;
        $self->app->core->connect($connection);
        $self->$cb({data => $connection->TO_JSON});
      },
    );
    1;
  } or do {
    my $e = $@ || 'Unknwon error';
    $e =~ s! at \S+.*!!s;
    $e =~ s!:.*!.!s;
    $self->$cb(ce $e, '/', 400);
  };
}

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @connections;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    push @connections, $connection->TO_JSON;
  }

  $self->$cb({data => {connections => \@connections}});
}

sub remove {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  $self->delay(
    sub {
      $user->remove_connection($args->{connection_id}, shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->$cb({data => {}}, 200);
    },
  );
}

sub rooms {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id});

  unless ($connection) {
    return $self->$cb(ce 'Connection not found.', 404);
  }

  $self->delay(
    sub { $connection->rooms(shift->begin) },
    sub {
      my ($delay, $err, $rooms) = @_;
      $self->$cb({data => {rooms => $rooms}});
    },
  );
}

sub update {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $state = $args->{state} || '';
  my $url = Mojo::URL->new($args->{url} || '');
  my $connection;

  eval {
    $connection = $user->get_connection($args->{connection_id});
    $connection->url->host or die 'Connection not found';
  } or do {
    return $self->$cb(ce 'Connection not found.', 404);
  };

  if ($url->host) {
    $url->scheme($args->{protocol});
    $state = 'reconnect' if $url->to_string ne $connection->url->to_string;
    $connection->url->parse($url);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $connection->save($delay->begin);
      $connection->disconnect($delay->begin) if $state eq 'disconnect' or $state eq 'reconnect';
    },
    sub {
      my ($delay, $err, $disconnected) = @_;
      die $err if $err;
      $self->app->core->connect($connection) if $state eq 'connect' or $state eq 'reconnect';
      $self->$cb({data => $connection->TO_JSON});
    },
  );
}

sub _pretty_connection_name {
  my ($self, $name) = @_;

  return '' unless defined $name;
  return 'magnet' if $name =~ /\birc\.perl\.org\b/i;    # also match ssl.irc.perl.org
  return 'efnet'  if $name =~ /\befnet\b/i;

  $name =~ s!^(irc|chat)\.!!;                           # remove common prefixes from server name
  $name =~ s!:\d+$!!;                                   # remove port
  $name =~ s!\.\w{2,3}$!!;                              # remove .com, .no, ...
  $name =~ s![\W_]+!-!g;                                # make pretty url
  $name;
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Connection - Convos connection actions

=head1 DESCRIPTION

L<Convos::Controller::Connection> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 create

=head2 list

=head2 remove

=head2 rooms

=head2 update

=head1 SEE ALSO

L<Convos>

=cut
