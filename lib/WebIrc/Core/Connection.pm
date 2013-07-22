package WebIrc::Core::Connection;

=head1 NAME

WebIrc::Core::Connection - Represents a connection to an IRC server

=head1 SYNOPSIS

  use WebIrc::Core::Connection;

  $c = WebIrc::Core::Connection->new(
          id => 'foobar',
          redis => Mojo::Redis->new,
        );

  $c->connect;

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

L</irc_rpl_welcome>, L</irc_rpl_myinfo>, L</irc_join>, L</irc_part>,
L</irc_rpl_namreply>, L</irc_err_nosuchchannel> L</irc_err_notonchannel>
L</irc_err_bannedfromchan> and l</irc_error>.

=back

=cut

use Mojo::Base -base;
use Mojo::IRC;
use Mojo::JSON;
no warnings 'utf8';
use Carp qw/ croak /;
use IRC::Utils;
use Parse::IRC ();
use Scalar::Util ();
use Time::HiRes qw/ time /;
use WebIrc::Core::Util qw/ as_id /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $JSON = Mojo::JSON->new;
my @keys = qw/ nick user host /;

=head1 ATTRIBUTES

=head2 id

Holds the id of this connection. This attribute is required.

=cut

has id => 0;

=head2 uid

The user ID.

=cut

has uid => 0;

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has redis => sub { Mojo::Redis->new(timeout => 0); };

=head2 channels

IRC channels to join. The channel list will be fetched from the L</redis>
server by L</connect>.

=cut

has channels => sub { [] };

=head2 real_host

The actual IRC server connected to. Will be set by L</irc_rpl_welcome>.

=cut

has real_host => '';

=head2 log

Holds a L<Mojo::Log> object.

=cut

has log => sub { Mojo::Log->new };

my @ADD_MESSAGE_EVENTS        = qw/ irc_privmsg /;
my @ADD_SERVER_MESSAGE_EVENTS = qw/
  irc_rpl_yourhost irc_rpl_motdstart irc_rpl_motd irc_rpl_endofmotd
  irc_rpl_welcome
/;
my @OTHER_EVENTS              = qw/
  irc_rpl_welcome irc_rpl_myinfo irc_join irc_nick irc_part irc_rpl_namreply
  irc_error irc_rpl_whoisuser irc_rpl_whoischannels irc_rpl_topic irc_topic
  irc_rpl_topicwhotime irc_rpl_notopic irc_err_nosuchchannel
  irc_err_notonchannel irc_err_bannedfromchan
/;

has _irc => sub {
  my $self = shift;
  my $irc  = Mojo::IRC->new(debug_key => $self->id);

  Scalar::Util::weaken($self);
  $irc->register_default_event_handlers;
  $irc->on(
    close => sub {
      my $irc = shift;
      $self->{stop} and return;
      $self->_publish(wirc_notice => { message => "Disconnected from @{[$irc->server]}. Attempting reconnect in @{[$self->_reconnect_in]} seconds." });
      $irc->ioloop->timer($self->_reconnect_in, sub { $self->_connect });
    }
  );

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

has _reconnect_in => 10;

=head1 METHODS

=head2 connect

  $self = $self->connect;

This method will create a new L<Mojo::IRC> object with attribute data from
L</redis>. The values fetched from the backend is identified by L</id>. This
method then call L<Mojo::IRC/connect> after the object is set up.

Attributes fetched from backend: nick, user, host and channels. The latter
is set in L</channels> and used by L</irc_rpl_welcome>.

=cut

sub connect {
  my ($self) = @_;
  my $irc = $self->_irc;
  my $id = $self->id or croak "Cannot load connection without id";

  # we will try to "steal" the nich we want every 60 second
  Scalar::Util::weaken($self);
  $self->{keepnick_tid} ||= $irc->ioloop->recurring(60, sub {
    $self->redis->hget("connection:$id", "nick", sub { $irc->change_nick($_[1]) });
  });

  $self->_connect;
  $self->_subscribe;
  $self;
}

sub _subscribe {
  my $self = shift;
  my $id = $self->id;
  my $irc = $self->_irc;

  Scalar::Util::weaken($self);
  $self->{messages} = $self->redis->subscribe("connection:$id:to_server");
  $self->{messages}->timeout(0);
  $self->{messages}->on(
    error => sub {
      my ($sub, $error) = @_;
      $self->log->warn("[$id] Re-subcribing to messages to @{[$irc->server]}. ($error)");
      $self->_subscribe;
    },
  );
  $self->{messages}->on(
    message => sub {
      my ($sub, $raw_message) = @_;
      my $message = Parse::IRC::parse_irc(sprintf ':%s %s', $irc->nick, $raw_message);

      unless(ref $message) {
        $self->_publish(wirc_notice => { message => "Unable to parse: $raw_message" });
        return;
      }

      $irc->write($raw_message, sub {
        my($irc, $error) = @_;

        if($error) {
          $self->_publish(wirc_notice => { message => "Could not send message to @{[$irc->server]}: $error" });
        }
        elsif($message->{command} eq 'PRIVMSG') {
          $self->add_message($message);
        }
        elsif(my $method = $self->can('cmd_' . lc $message->{command})) {
          $self->$method($message);
        }
      });
    }
  );

  $self;
}

sub _connect {
  my $self = shift;
  my $id = $self->id;
  my $irc = $self->_irc;

  Scalar::Util::weaken($self);
  $self->redis->execute(
    [hgetall  => "connection:$id"],
    [smembers => "connection:$id:channels"],
    sub {
      my ($redis, $attrs, $channels) = @_;

      $self->channels($channels);
      $irc->server($attrs->{host});
      $irc->nick($attrs->{nick});
      $irc->user($attrs->{user});
      $irc->connect(sub {
        my($irc, $error) = @_;

        if($error) {
          $self->_publish(wirc_notice => { message => "Could not connect to @{[$irc->server]}: $error" });
          $irc->ioloop->timer($self->_reconnect_in, sub { $self->_connect });
        }
        else {
          $self->redis->hset("connection:@{[$self->id]}", current_nick => $irc->nick);
          $self->_publish(wirc_notice => { message => "Connected to @{[$irc->server]}." });
        }
      });
    },
  );
}

=head2 add_server_message

  $self->add_server_message(\%message);

Will look at L<%message> and add it to the database as a server message
if it looks like one. Returns true if the message was added to redis.

=cut

sub add_server_message {
  my ($self, $message) = @_;
  my $timestamp = time;

  if (!$message->{prefix} or $message->{prefix} eq $self->real_host) {

    # 1 = normal, 0 = error
    my $params = $message->{params};
    shift $params;
    $self->_publish(
      server_message => {
        message => join(' ', @{$message->{params}}),
        save => 1,
        status => 200,
        timestamp => $timestamp,
      },
    );
  }
}

=head2 add_message

  $self->add_message(\%message);

Will add a private message to the database.

=cut

sub add_message {
  my ($self, $message) = @_;
  my $current_nick = $self->_irc->nick;
  my $is_private_message = $message->{params}[0] eq $current_nick;
  my $data = {
    cid => $self->id,
    highlight => 0,
    message => $message->{params}[1],
    save => 1,
    timestamp => time,
  };

  @$data{qw/ nick user host /} = IRC::Utils::parse_user($message->{prefix}) if $message->{prefix};
  $data->{target} = lc($is_private_message ? $data->{nick} : $message->{params}[0]);
  $data->{host} ||= WebIrc::Core::Util::hostname;
  $data->{user} ||= $self->_irc->user;

  if($data->{nick} ne $current_nick) {
    if($is_private_message or $data->{message} =~ /\b$current_nick\b/) {
      $data->{highlight} = 1;
      $self->redis->lpush("user:@{[$self->uid]}:notifications", $JSON->encode($data));
    }
  }

  $self->_publish(
    $data->{message} =~ s/\x{1}ACTION (.*)\x{1}/$1/ ? 'action_message' : 'message',
    $data,
  );
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  my($self, $cb) = @_;
  $self->{stop} = 1;
  $self->_irc->disconnect($cb || sub {});
}

=head1 EVENT HANDLERS

=head2 irc_rpl_welcome

Example message:

:Zurich.CH.EU.Undernet.Org 001 somenick :Welcome to the UnderNet IRC Network, somenick

=cut

sub irc_rpl_welcome {
  my ($self, $message) = @_;

  $self->real_host($message->{prefix});

  for my $channel (@{$self->channels}) {
    $self->_irc->write(JOIN => $channel);
  }
}

=head2 irc_rpl_whoisuser

Reply with user info

=cut

sub irc_rpl_whoisuser {
  my ($self, $message) = @_;

  $self->_publish(
    whois => {
      nick     => $message->{params}[1],
      user     => $message->{params}[2],
      host     => $message->{params}[3],
      realname => $message->{params}[5],
    }
  );
}

=head2 irc_rpl_whoischannels

Reply with user channels

=cut

sub irc_rpl_whoischannels {
  my ($self, $message) = @_;

  $self->_publish(
    whois_channels => {
      nick => $message->{params}[1],
      channels => [sort split ' ', $message->{params}[2] || ''],
    },
  );
}

=head2 irc_rpl_notopic

  :server 331 nick #channel :No topic is set.

=cut

sub irc_rpl_notopic {
  my ($self, $message) = @_;

  $self->_publish(topic => { topic => '', target => $message->{params}[1] });
}

=head2 irc_rpl_topic

Reply with topic

=cut

sub irc_rpl_topic {
  my ($self, $message) = @_;

  $self->_publish(topic => { topic => $message->{params}[2], target => $message->{params}[1] });
}

=head2 irc_topic

    :nick!~user@hostname TOPIC #channel :some topic

=cut

sub irc_topic {
  my ($self, $message) = @_;

  $self->_publish(topic => { topic => $message->{params}[1], target => $message->{params}[0] });
}

=head2 irc_rpl_topicwhotime

Reply with who and when for topic change

=cut

sub irc_rpl_topicwhotime {
  my ($self, $message) = @_;

  $self->_publish(
    topic_by => {
      ts     => $message->{params}[3],
      nick   => $message->{params}[2],
      target => $message->{params}[1],
    }
  );
}

=head2 irc_rpl_myinfo

Example message:

:Tampa.FL.US.Undernet.org 004 somenick Tampa.FL.US.Undernet.org u2.10.12.14 dioswkgx biklmnopstvrDR bklov

=cut

sub irc_rpl_myinfo {
  my ($self, $message) = @_;
  my @keys = qw/ current_nick real_host version available_user_modes available_channel_modes /;
  my $i    = 0;

  $self->redis->hmset("connection:@{[$self->id]}", map { $_, $message->{params}[$i++] // '' } @keys);
}

=head2 irc_join

See L<Mojo::IRC/irc_join>.

=cut

sub irc_join {
  my ($self, $message) = @_;
  my ($nick) = IRC::Utils::parse_user($message->{prefix});
  my $channel = $message->{params}[0];

  if($nick eq $self->_irc->nick) {
    my $id = as_id $self->id, $channel;
    $self->redis->zadd("user:@{[$self->uid]}:conversations", time, $id);
    $self->_publish(add_conversation => { target => $channel });
  }

  $self->_publish(nick_joined => { nick => $nick, target => $channel });
}

=head2 irc_nick

  :old_nick!~username@1.2.3.4 NICK :new_nick

=cut

sub irc_nick {
  my ($self, $message) = @_;
  my ($old_nick) = IRC::Utils::parse_user($message->{prefix});
  my $new_nick = $message->{params}[0];

  if ($new_nick eq $self->_irc->nick) {
    $self->redis->hset("connection:@{[$self->id]}", current_nick => $new_nick);
  }

  $self->_publish(nick_change => { old_nick => $old_nick, new_nick => $new_nick });
}

=head2 irc_part

=cut

sub irc_part {
  my ($self, $message) = @_;
  my ($nick) = IRC::Utils::parse_user($message->{prefix});
  my $channel = $message->{params}[0];

  Scalar::Util::weaken($self);
  if($nick eq $self->_irc->nick) {
    my $id = as_id $self->id, $channel;
    $self->redis->srem("connection:@{[$self->id]}:channels", $channel);
    $self->redis->zrem("user:@{[$self->uid]}:conversations", $id, sub {
      $self->_publish(remove_conversation => { cid => $self->id, target => $channel, });
    });
  }
  else {
    $self->_publish(nick_parted => { nick => $nick, target => $channel });
  }
}

=head2 irc_err_bannedfromchan

:electret.shadowcat.co.uk 474 nick #channel :Cannot join channel (+b)

=cut

sub irc_err_bannedfromchan {
  my($self, $message) = @_;
  my $channel = $message->{params}[1];
  my $id = as_id $self->id, $channel;

  Scalar::Util::weaken($self);
  $self->redis->zrem("user:@{[$self->uid]}:conversations", $id, sub {
    $self->_publish(remove_conversation => { cid => $self->id, target => $channel });
    $self->_publish(wirc_notice => { message => $message->{params}[2] });
  });
}

=head2 irc_err_nosuchchannel

:astral.shadowcat.co.uk 403 nick #channel :No such channel

=cut

sub irc_err_nosuchchannel {
  my ($self, $message) = @_;
  my $channel = $message->{params}[1];
  my $id = as_id $self->id, $channel;

  Scalar::Util::weaken($self);
  $self->redis->zrem("user:@{[$self->uid]}:conversations", $id, sub {
    $self->_publish(remove_conversation => { cid => $self->id, target => $channel });
  });
}

=head2 irc_err_notonchannel

:electret.shadowcat.co.uk 442 nick #channel :You're not on that channel

=cut

sub irc_err_notonchannel {
  shift->irc_err_nosuchchannel(@_);
}

=head2 irc_rpl_namreply

Example message:

:Budapest.Hu.Eu.Undernet.org 353 somenick = #html :somenick Indig0 Wildblue @HTML @CSS @Luch1an @Steaua_ Indig0_ Pilum @fade

=cut

sub irc_rpl_namreply {
  my ($self, $message) = @_;
  my @nicks;

  for(sort { lc $a cmp lc $b } split /\s+/, $message->{params}[3]) { # 3 = "+nick0 @nick1 nick2"
    my $mode = s/^(\W)// ? $1 : '';
    push @nicks, { nick => $_, mode => $mode };
  }

  $self->_publish(rpl_namreply => {
    nicks => \@nicks,
    target => $message->{params}[2],
  });
}

=head2 irc_error

Example message:

ERROR :Closing Link: somenick by Tampa.FL.US.Undernet.org (Sorry, your connection class is full - try again later or try another server)

=cut

sub irc_error {
  my ($self, $message) = @_;
  $self->add_server_message($message);
  if ($message->{raw_line} =~ /Closing Link/i) {
    $self->log->warn("[connection:@{[$self->id]}] ! Closing link (reconnect)");
  }
}

=head2 cmd_nick

Handle nick commands from user. Change nick and set new nick in redis.

=cut

sub cmd_nick {
  my ($self, $message) = @_;
  my $new_nick = $message->{params}[0];
  $self->redis->hset("connection:@{[$self->id]}", nick => $new_nick);
  $self->_irc->nick($new_nick);
}

=head2 cmd_join

Handle join commands from user. Add to channel set.

=cut

sub cmd_join {
  my ($self, $message) = @_;
  my $channel = $message->{params}[0];

  return $self->_publish(wirc_notice => { message => 'Channel to join is required' }) unless $channel;
  return $self->_publish(wirc_notice => { message => 'Channel must start with & or #' }) unless $channel =~ /^[#&]/x;

  Scalar::Util::weaken($self);
  $self->redis->sadd("connection:@{[$self->id]}:channels", $channel, sub {
    my($redis, $added) = @_;
    my $id = as_id $self->id, $channel;
    $redis->zadd("user:@{[$self->uid]}:conversations", time, $id);
    $self->_publish(add_conversation => { target => $channel }) unless $added;
  });
}

sub _publish {
  my ($self, $event, $data) = @_;
  my $message;

  $data->{cid} //= $self->id;
  $data->{timestamp} ||= time;
  $data->{event} = $event;
  $message = $JSON->encode($data);

  $self->redis->publish("connection:$data->{cid}:from_server", $message);

  if($event eq 'wirc_notice') {
    $self->log->warn("[$data->{cid}] $data->{message}");
  }
  if($data->{save}) {
    if ($data->{target}) {
      $self->redis->zadd("connection:$data->{cid}:$data->{target}:msg", $data->{timestamp}, $message);
    }
    else {
      $self->redis->zadd("connection:$data->{cid}:msg", $data->{timestamp}, $message);
    }
  }
}

sub DESTROY {
  warn "DESTROY $_[0]->{id}\n" if DEBUG;
  my $self = shift;
  my $ioloop = $self->{_irc}{ioloop} or return;
  my $keepnick_tid = $self->{keepnick_tid} or return;
  $ioloop->remove($keepnick_tid);
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
