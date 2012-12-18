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
use Unicode::UTF8;
no warnings "utf8";
use Mojo::JSON;
use WebIrc::Core::Util qw/ pack_irc /;
use Parse::IRC ();
use IRC::Utils qw/parse_user/;
use Scalar::Util qw/ weaken /;
use Carp qw/ croak /;
use Time::HiRes qw/time/;

# default to true while developing
use constant DEBUG => $ENV{WIRC_DEBUG} // 1;

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

=head2 log

Holds a L<Mojo::Log> object.

=cut

has log => sub { Mojo::Log->new };

my @ADD_MESSAGE_EVENTS        = qw/ irc_privmsg /;
my @ADD_SERVER_MESSAGE_EVENTS = qw/ irc_rpl_yourhost irc_rpl_motdstart irc_rpl_motd irc_rpl_endofmotd irc_rpl_welcome /;
my @OTHER_EVENTS              = qw/ irc_rpl_welcome irc_rpl_myinfo irc_join irc_nick irc_rpl_namreply irc_error /;

has _irc => sub {
  my $self = shift;
  my $irc  = Mojo::IRC->new;

  weaken $self;
  $irc->register_default_event_handlers;
  $irc->on(close => sub {
    $self->log->debug('Reconnecting on close...');
    $self->_irc->ioloop->timer(30, sub { $self->connect(sub {}); });
  });
  $irc->on(error => sub {
    $self->log->error("Reconnecting on error: $_[1]");
    $self->_irc->ioloop->timer(2, sub { $self->connect(sub {}); });
  });

  for my $event (@ADD_MESSAGE_EVENTS) {
    $irc->on($event => sub { $self->add_message($_[1]) });
  }
  for my $event (@ADD_SERVER_MESSAGE_EVENTS) {
    $irc->on($event => sub { $self->add_server_message($_[1]) });
  }
  for my $event (@OTHER_EVENTS) {
    $irc->on($event => sub { $self->$event($_[1]) });
  }

  $irc;
};

=head1 METHODS

=head2 connect

  $self = $self->connect($callback);

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
    [smembers => "connection:$id:channels"],
    sub {
      my ($redis, $attrs, $channels) = @_;

      $self->channels($channels);
      $self->_irc->server($attrs->{host});
      $self->_irc->nick($attrs->{nick});
      $self->_irc->user($attrs->{user});
      $self->_irc->connect(sub { $self->$cb; });
      $self->{sub} = $redis->subscribe("connection:$id:to_server");
      $self->{sub}->on(message => sub {
        my($sub, $msg) = @_;
        $msg=Unicode::UTF8::encode_utf8($msg, sub { $_[0] });
        $self->_irc->write($msg);
        $msg = Parse::IRC::parse_irc(sprintf ':%s %s', $self->_irc->nick, $msg);
        if($msg->{command} eq 'PRIVMSG') {
          $self->add_message($msg);
        }
        else {
          my $action='cmd_'.lc($msg->{command});
          $self->$action($msg) if $self->can($action);
        }
        
      }) if $self->{sub};
    }
  );
  $self;
};

=head2 add_server_message

  $self->add_server_message(\%message);

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
        sender    => $self->_irc->server,
        message   => $message->{params}[1] || $message->{params}[0],                   # 1 = normal, 0 = error
        server    => $self->_irc->server,
    });
  }
}

=head2 add_message

  $self->add_message(\%message);

Will add a private message to the database.

=cut

sub add_message {
  my ($self, $message) = @_;
  my $time = time;
  my $target= $message->{params}->[0] =~ /^\#/x ?$message->{params}->[0]:  parse_user($message->{prefix});

  $self->redis->zadd(
    "connection:@{[$self->id]}:$target:msg",
    $time, $message->{raw_line}
  );
  my ($nick, $user, $host) = parse_user($message->{prefix});
  $self->_publish({
    timestamp => $time,
    server    => $self->_irc->server,
    nick      => $nick,
    user      => $user,
    host      => $host,
    target    => $message->{params}[0],
    message   => $message->{params}[1],
  });

  unless ($message->{params}->[0] =~ /^\#/x || $target eq $self->_irc->nick) {    # not a channel
    $self->redis->sadd("connection:@{[$self->id]}:conversations", $target);
  }
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  $_[0]->_irc->disconnect($_[1] || sub {});
}

=head1 EVENT HANDLERS

=head2 irc_rpl_welcome

Example message:

:Zurich.CH.EU.Undernet.Org 001 somenick :Welcome to the UnderNet IRC Network, somenick

=cut

sub irc_rpl_welcome {
  my ($self, $message) = @_;

  $self->real_host($message->{prefix});

  for my $channel (@{ $self->channels }) {
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

  $self->redis->hmset("connection:@{[$self->id]}", map { $_, $message->{params}[$i++] // '' } @keys);
}

=head2 irc_join

Example message:

:somenick!~someuser@148.122.202.168 JOIN #html

=cut

sub irc_join {
  my ($self, $message) = @_;
  my ($nick, $user, $host) = parse_user($message->{prefix});
  $self->_publish({ nick=>$nick, user => $user,host=>$host, joined => $message->{params}[0], timestamp => time });
  return if $nick eq $self->_irc->nick;
  $self->redis->sadd("connection:@{[$self->id]}:$message->{params}[0]:nicks", $nick);
}

=head2 irc_nick

=cut

sub irc_nick {
  my ($self, $message) = @_;
  my $old_nick = ($message->{prefix} =~ /^(.*?)!/)[0] || '';
  my $new_nick = $message->{params}[0];

  if($old_nick eq $self->_irc->nick) {
    $self->redis->hset("connection:@{[$self->id]}", nick => $new_nick);
  }

  $self->_publish({ old_nick => $old_nick, new_nick => $new_nick, timestamp => time });
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
  $self->add_server_message($message);
  if ($message->{raw_line} =~ /Closing Link/i) {
    $self->log(warn => "[connection:@{[$self->id]}] ! Closing link (reconnect)");
    delete $self->{_irc};
  }
}

sub _publish {
  my($self, $data) = @_;
  $data->{cid}=$self->id;
  $self->redis->publish("connection:@{[$self->id]}:from_server", $JSON->encode($data));
}


=head1 cmd_join

Handle join commands from user. Add to channel set.

=cut

sub cmd_join {
  my($self,$msg)=@_;
  $self->redis->sadd("connection:@{[$self->id]}:channels",@{$msg->{params}});

}

=head1 cmd_part

Handle part commands from user. Remove from channel set.

=cut

sub cmd_part {
  my($self,$msg)=@_;
  $self->redis->srem("connection:@{[$self->id]}:channels",@{$msg->{params}});
  $self->redis->del("connection:@{[$self->id]}:channel:$msg->{params}[0]:nicks");
  $self->_publish({ parted => $msg->{params}[0], timestamp => time });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
