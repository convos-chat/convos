package WebIrc::Core::Connection;

=head1 NAME

WebIrc::Core::Connection - Represents a connection to an IRC server

=head1 SYNOPSIS

  use WebIrc::Core::Connection;

  $c = WebIrc::Core::Connection->new(
          id => 'foobar',
          redis => Mojo::Redis->new,
        );

  $c->connect(sub {
    warn "I am connected to the irc server!";
  });

  Mojo::IOLoop->start;

=head1 DESCRIPTION

This module use L<Mojo::IRC> to set up a connection to an IRC server. The
attributes used to do so is figured out from a redis server.

There are quite a few L<EVENTS|Mojo::IRC/EVENTS> that this module use:

=over 4

=item * L</add_message> events

L<Mojo::IRC/privmsg>.

=item * L</add_server_message> events

L<Mojo::IRC/rpl_yourhost>, L<Mojo::IRC/rpl_motdstart>, L<Mojo::IRC/rpl_motd>,
L<Mojo::IRC/rpl_endofmotd>, L<Mojo::IRC/rpl_welcome> and L<Mojo::IRC/error>.

=item * Other events

L</irc_rpl_welcome>, L</irc_rpl_myinfo>, L</irc_join>, L<irc_rpl_namreply> and
l</irc_error>.

=back

=cut

use Mojo::Base -base;
use Mojo::IRC;
use Mojo::JSON;
use WebIrc::Core::Util qw/ pack_irc /;
use Parse::IRC ();
use Scalar::Util qw/ weaken /;
use Carp qw/ croak /;
use Time::HiRes qw/time/;

# default to true while developing
use constant DEBUG => $ENV{'WIRC_DEBUG'} // 1;

my $JSON = Mojo::JSON->new;
my @keys = qw/ nick user host /;

=head1 ATTRIBUTES

=head2 id

Holds the id of this connection. This attribute is required.

=cut

has id => 0;

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has redis => sub { Mojo::Redis->new };

=head2 channels

IRC channels to join. The channel list will be fetched from the L</redis>
server by L</connect>.

=cut

has channels => '';

=head2 real_host

The actual IRC server connected to. Will be set by L</irc_rpl_welcome>.

=cut

has real_host => '';

my @ADD_MESSAGE_EVENTS        = qw/ irc_privmsg /;
my @ADD_SERVER_MESSAGE_EVENTS = qw/ irc_rpl_yourhost irc_rpl_motdstart irc_rpl_motd irc_rpl_endofmotd irc_rpl_welcome /;
my @OTHER_EVENTS              = qw/ irc_rpl_welcome irc_rpl_myinfo irc_join irc_rpl_namreply irc_error /;

has _irc => sub {
  my $self = shift;
  my $irc  = Mojo::IRC->new;

  weaken $self;
  $irc->register_default_event_handlers;
  $irc->on(close => sub { delete $self->{_irc} });

  for my $event (@ADD_MESSAGE_EVENTS) {
    $irc->on($event => sub { $self->add_message($_[1]) });
  }
  for my $event (@ADD_SERVER_MESSAGE_EVENTS) {
    $irc->on($event => sub { $self->add_server_message($_[1]) });
  }
  for my $event (@OTHER_EVENTS) {
    my $method = "$event";
    $irc->on($event => sub { $self->$method($_[1]) });
  }

  $irc;
};

=head1 METHODS

=head2 connect

  $self = $self->connect(\&callback);

This method will create a new L<Mojo::IRC> object with attribute data from
L</redis>. The values fetched from the backend is identified by L</id>. This
method then call L<Mojo::IRC/connect> after the object is set up.

Attributes fetched from backend: nick, user, host and channels. The latter
is set in L</channels> and used by L</irc_rpl_welcome>.

=cut

sub connect {
  my ($self, $cb) = @_;
  my $id = $self->id or croak "Cannot load connection without id";

  $self->redis->execute(
    [hgetall  => "connection:$id"],
    sub {
      my ($redis, $attrs) = @_;

      $self->channels($attrs->{channels});
      $self->_irc->host($attrs->{host});
      $self->_irc->nick($attrs->{nick});
      $self->_irc->user($attrs->{user});
      $self->_irc->connect($cb);
      $self->redis->subscribe("connection:$id:to_server", sub {
        for(@{ $_[1] }) {
          next unless /^[A-Z]+/; # avoid "0: subscribe", "1: ...", ...
          $self->_irc->write($_);
          utf8::encode($_);
          my $msg = Parse::IRC::parse_irc(sprintf ':%s %s', $self->_irc->nick, $_);
          $self->add_message($msg);
        }
      });
    }
  );

  $self;
}

=head2 add_server_message

  $bool = $self->add_server_message(\%message);

Will look at L<%message> and add it to the database as a server message
if it looks like one. Returns true if the message was added to redis.

=cut

sub add_server_message {
  my ($self, $message) = @_;
  my $time = time;

  if (!$message->{prefix} or $message->{prefix} eq $self->real_host) {
    $self->redis->zadd("connection:@{[$self->id]}:msg", $time, $message->{raw_line});
    $self->_publish({
        timestamp => $time,
        sender    => $self->_irc->host,
        message   => $message->{params}[1] || $message->{params}[0],                   # 1 = normal, 0 = error
        server    => $self->_irc->host,
    });
    return 1;
  }

  return;
}

=head2 add_message

  $self->add_message(\%message);

Will add a private message to the database.

=cut

sub add_message {
  my ($self, $message) = @_;
  my $time = time;

  $self->redis->zadd(
    "connection:@{[$self->id]}:$message->{params}[0]:msg",
    $time, $message->{raw_line}
  );
  $self->_publish({
    timestamp => $time,
    server    => $self->_irc->host,
    sender    => $message->{prefix},
    target    => $message->{params}[0],
    message   => $message->{params}[1],
  });

  unless ($message->{params}->[0] =~ /^\#/x) {    # not a channel
    $self->redis->sadd("connection:@{[$self->id]}:conversations", $message->{params}[0]);
  }
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  $_[0]->_irc->disconnect($_[1] || sub { });
}

=head1 EVENT HANDLERS

=head2 irc_rpl_welcome

Example message:

:Zurich.CH.EU.Undernet.Org 001 somenick :Welcome to the UnderNet IRC Network, somenick

=cut

sub irc_rpl_welcome {
  my ($self, $message) = @_;

  $self->real_host($message->{prefix});

  for my $channel (split /,/, $self->channels) {
    $self->_irc->write(JOIN => $channel);
  }
}

=head2 irc_rpl_myinfo

Example message:

:Tampa.FL.US.Undernet.org 004 somenick Tampa.FL.US.Undernet.org u2.10.12.14 dioswkgx biklmnopstvrDR bklov

=cut

sub irc_rpl_myinfo {
  my ($self, $message) = @_;
  my @keys = qw/ nick real_host version available_user_modes available_channel_modes /;
  my $i = 0;

  $self->_irc->nick($message->{params}[0]);
  $self->redis->hmset("connection:@{[$self->id]}", map { $_, $message->{params}[$i++] // '' } @keys);
}

=head2 irc_join

Example message:

:somenick!~someuser@148.122.202.168 JOIN #html

=cut

sub irc_join {
  my ($self, $message) = @_;

  $self->_publish({joined => $message->{params}[0], timestamp => time});
}

=head2 irc_rpl_namreply

Example message:

:Budapest.Hu.Eu.Undernet.org 353 somenick = #html :somenick Indig0 Wildblue @HTML @CSS @Luch1an @Steaua_ Indig0_ Pilum @fade

=cut

sub irc_rpl_namreply {
  my ($self, $message) = @_;
  my @nicks = split /\s+/, $message->{params}[3];    # 3 = +nick0 @nick1, nick2

  $self->redis->sadd("connection:@{[$self->id]}:$message->{params}[2]:nicks", @nicks);
}

=head2 irc_error

Example message:

ERROR :Closing Link: somenick by Tampa.FL.US.Undernet.org (Sorry, your connection class is full - try again later or try another server)

=cut

sub irc_error {
  my ($self, $message) = @_;
  #warn Data::Dumper::Dumper($message);
  if ($message->{raw_line} =~ /Closing Link/i) {
    warn sprintf "[connection:%s] ! Closing link (reconnect)\n", $self->_irc->disconnect(
      sub {
        $self->connect(sub { });
      }
    );
  }
}

=head2 error

TODO

=cut

sub error {
  warn "Handle ".@_;
}

sub _publish {
  my($self, $data) = @_;

  $self->redis->publish("connection:@{[$self->id]}:from_server", $JSON->encode($data));
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
