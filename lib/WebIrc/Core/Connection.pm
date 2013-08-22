package WebIrc::Core::Connection;

=head1 NAME

WebIrc::Core::Connection - Represents a connection to an IRC server

=head1 SYNOPSIS

  use WebIrc::Core::Connection;

  $c = WebIrc::Core::Connection->new(
          host => 'irc.localhost',
          uid => 123,
          redis => Mojo::Redis->new,
        );

  $c->connect;

  Mojo::IOLoop->start;

=head1 DESCRIPTION

This module use L<Mojo::IRC> to  up a connection to an IRC server. The
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
use IRC::Utils;
use Parse::IRC ();
use Scalar::Util ();
use Time::HiRes qw/ time /;
use WebIrc::Core::Util qw/ as_id /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $JSON = Mojo::JSON->new;
my @keys = qw/ nick user host /;

=head1 ATTRIBUTES

=head2 host

=cut

has host => '';

=head2 uid

The user ID.

=cut

has uid => 0;

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has redis => sub { Mojo::Redis->new(timeout => 0); };

=head2 channels

  @channels = $self->channels;
  $self = $self->channels(add => $add_channel_name);
  $self = $self->channels(del => $del_channel_name);

IRC channels to join. The channel list will be fetched from the L</redis>
server by L</connect>.

=cut

sub channels {
  my $self = shift;
  return sort keys %{ $self->{channels} || {} } unless @_;
  $_[0] eq 'add' ? $self->{channels}{$_[1]} = 1 : delete $self->{channels}{$_[1]};
  $self;
}

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
  irc_err_notonchannel irc_err_bannedfromchan irc_rpl_liststart irc_rpl_list
  irc_rpl_listend irc_mode
/;

has _irc => sub {
  my $self = shift;
  my $irc  = Mojo::IRC->new(debug_key => join ':', $self->uid, $self->host);

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

=head2 new

Checks for mandatory attributes: L</uid> and L</host>.

=cut

sub new {
  my $self = shift->SUPER::new(@_);

  $self->uid or die "uid is required";
  $self->host or die "host is required";
  $self->{path} = "user:$self->{uid}:connection:$self->{host}";
  $self;
}

=head2 connect

  $self = $self->connect;

This method will create a new L<Mojo::IRC> object with attribute data from
L</redis>. The values fetched from the backend is identified by L</host> and
L</uid>. This method then call L<Mojo::IRC/connect> after the object is set
up.

Attributes fetched from backend: nick, user, host and channels. The latter
is set in L</channels> and used by L</irc_rpl_welcome>.

=cut

sub connect {
  my ($self) = @_;
  my $irc = $self->_irc;

  # we will try to "steal" the nich we want every 60 second
  Scalar::Util::weaken($self);
  $self->{keepnick_tid} ||= $irc->ioloop->recurring(60, sub {
    $self->redis->hget($self->{path}, 'nick', sub { $irc->change_nick($_[1]) });
  });

  $self->_connect;
  $self->_subscribe;
  $self;
}

sub _subscribe {
  my $self = shift;
  my $irc = $self->_irc;
  my $uid = $self->uid;

  Scalar::Util::weaken($self);
  $self->{messages} = $self->redis->subscribe("wirc:user:$uid:in");
  $self->{messages}->timeout(0);
  $self->{messages}->on(
    error => sub {
      my ($sub, $error) = @_;
      $self->log->warn("[$self->{path}] Re-subcribing to messages to @{[$irc->server]}. ($error)");
      $self->_subscribe;
    },
  );
  $self->{messages}->on(
    message => sub {
      my ($sub, $raw_message) = @_;
      my($uuid, $message);

      $raw_message =~ s/(\S+)\s//;
      $uuid = $1;
      $raw_message = sprintf ':%s %s', $irc->nick, $raw_message;
      $message = Parse::IRC::parse_irc($raw_message);

      unless(ref $message) {
        $self->_publish(wirc_notice => { message => "Unable to parse: $raw_message", uuid => $uuid });
        return;
      }

      $message->{uuid} = $uuid;

      $irc->write($raw_message, sub {
        my($irc, $error) = @_;

        if($error) {
          $self->_publish(wirc_notice => { message => "Could not send message to @{[$irc->server]}: $error", uuid => $uuid, error => 1 });
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
  my $irc = $self->_irc;

  Scalar::Util::weaken($self);
  $self->redis->execute(
    [hgetall => $self->{path}],
    sub {
      my ($redis, $args) = @_;

      $self->channels(add => $_) for split ' ', $args->{channels};
      $irc->server($args->{host});
      $irc->nick($args->{nick});
      $irc->user($args->{user});
      $irc->connect(sub {
        my($irc, $error) = @_;

        if($error) {
          $irc->ioloop->timer($self->_reconnect_in, sub { $self->_connect });
          $self->_publish(wirc_notice => { message => "Could not connect to @{[$irc->server]}: $error" });
        }
        else {
          $self->redis->hset($self->{path}, current_nick => $irc->nick);
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
  my $params = $message->{params};

  shift @$params; # I think this removes our own nick... Not quite sure though
  $self->_publish(
    server_message => {
      message => join(' ', @$params),
      save => 1,
      status => 200,
    },
  );
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
    highlight => 0,
    message => $message->{params}[1],
    save => 1,
    timestamp => time,
    uuid => $message->{uuid},
  };

  @$data{qw/ nick user host /} = IRC::Utils::parse_user($message->{prefix}) if $message->{prefix};
  $data->{target} = lc($is_private_message ? $data->{nick} : $message->{params}[0]);
  $data->{host} ||= WebIrc::Core::Util::hostname;
  $data->{user} ||= $self->_irc->user;

  if($data->{nick} ne $current_nick) {
    if($is_private_message or $data->{message} =~ /\b$current_nick\b/) {
      $data->{highlight} = 1;
    }
    if($is_private_message) {
      $self->_add_conversation($data);
    }
  }

  $self->_publish(
    $data->{message} =~ s/\x{1}ACTION (.*)\x{1}/$1/ ? 'action_message' : 'message',
    $data,
  );
}

sub _add_conversation {
  my($self, $data) = @_;
  my $uid = $self->uid;
  my $name = as_id $self->host, $data->{target};

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->zincrby("user:$uid:conversations", 0, $name, $delay->begin);
    },
    sub {
      my($delay, $new) = @_;
      $new and return; # has a score
      $self->redis->zrevrange("user:$uid:conversations", 0, 0, 'WITHSCORES', $delay->begin);
    },
    sub {
      my($delay, $score) = @_;
      $self->redis->zadd("user:$uid:conversations", $score->[1] - 0.0001, $name, $delay->begin);
    },
    sub {
      my($delay) = @_;
      $self->_publish(add_conversation => { target => $data->{target} });
    },
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

  for my $channel ($self->channels) {
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
      timestamp => $message->{params}[3],
      nick      => $message->{params}[2],
      target    => $message->{params}[1],
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

  $self->redis->hmset($self->{path}, map { $_, $message->{params}[$i++] // '' } @keys);
}

=head2 irc_join

See L<Mojo::IRC/irc_join>.

=cut

sub irc_join {
  my ($self, $message) = @_;
  my ($nick) = IRC::Utils::parse_user($message->{prefix});
  my $channel = $message->{params}[0];

  if($nick eq $self->_irc->nick) {
    my $name = as_id $self->host, $channel;
    $self->redis->zadd("user:@{[$self->uid]}:conversations", time, $name);
    $self->_publish(add_conversation => { target => $channel });
  }
  else {
    $self->_publish(nick_joined => { nick => $nick, target => $channel });
  }
}

=head2 irc_nick

  :old_nick!~username@1.2.3.4 NICK :new_nick

=cut

sub irc_nick {
  my ($self, $message) = @_;
  my ($old_nick) = IRC::Utils::parse_user($message->{prefix});
  my $new_nick = $message->{params}[0];

  if ($new_nick eq $self->_irc->nick) {
    $self->redis->hset($self->{path}, current_nick => $new_nick);
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
    my $name = as_id $self->host, $channel;

    $self->channels(del => $channel);
    $self->redis->hset($self->{path}, 'channels', join ',', $self->channels);
    $self->redis->zrem("user:@{[$self->uid]}:conversations", $name, sub {
      $self->_publish(remove_conversation => { target => $channel });
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
  my $name = as_id $self->host, $channel;

  Scalar::Util::weaken($self);
  $self->redis->zrem("user:@{[$self->uid]}:conversations", $name, sub {
    $self->_publish(remove_conversation => { target => $channel });
    $self->_publish(wirc_notice => { save => 1, message => $message->{params}[2] });
  });
}

=head2 irc_err_nosuchchannel

:astral.shadowcat.co.uk 403 nick #channel :No such channel

=cut

sub irc_err_nosuchchannel {
  my ($self, $message) = @_;
  my $channel = $message->{params}[1];
  my $name = as_id $self->host, $channel;

  Scalar::Util::weaken($self);
  $self->redis->zrem("user:@{[$self->uid]}:conversations", $name, sub {
    $self->_publish(remove_conversation => { target => $channel });
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

=head2 irc_rpl_liststart

:servername 321 fooman Channel :Users  Name

=cut

sub irc_rpl_liststart {
  my($self, $message) = @_;

  $self->{channel_list} = [];
}

=head2 irc_rpl_list

:servername 322 somenick #channel 10 :[+n] some topic

=cut

sub irc_rpl_list {
  my($self, $message) = @_;

  push @{ $self->{channel_list} }, {
    name => $message->{params}[1],
    visible => $message->{params}[2],
    title => $message->{params}[3] || 'No title',
  };
}

=head2 irc_rpl_listend

:servername 323 somenick :End of /LIST

=cut

sub irc_rpl_listend {
  my($self, $message) = @_;

  $self->_publish(
    channel_list => {
      channel_list => $self->{channel_list},
    },
  );
}

=head2 irc_mode

:nick!user@host MODE #channel +o othernick

=cut

sub irc_mode {
  my($self, $message) = @_;

  $self->_publish(
    mode => {
      target => shift @{ $message->{params} },
      mode => shift @{ $message->{params} },
      args => join(' ', @{ $message->{params} }),
    },
  );
}

=head2 irc_error

Example message:

ERROR :Closing Link: somenick by Tampa.FL.US.Undernet.org (Sorry, your connection class is full - try again later or try another server)

=cut

sub irc_error {
  my ($self, $message) = @_;

  $self->_publish(
    server_message => {
      message => join(' ', @{$message->{params}}),
      save => 1,
      status => 500,
    },
  );
}

=head2 cmd_nick

Handle nick commands from user. Change nick and set new nick in redis.

=cut

sub cmd_nick {
  my ($self, $message) = @_;
  my $new_nick = $message->{params}[0];
  $self->redis->hset($self->{path}, nick => $new_nick);
  $self->_irc->nick($new_nick);
}

=head2 cmd_join

Handle join commands from user. Add to channel set.

=cut

sub cmd_join {
  my ($self, $message) = @_;
  my $channel = $message->{params}[0] || '';

  unless($channel =~ /^#\w/) {
    return $self->_publish(wirc_notice => { message => 'Do not understand which channel to join' });
  }

  Scalar::Util::weaken($self);
  $self->channels(add => $channel);
  $self->redis->hset($self->{path}, 'channels', join(',', $self->channels), sub {
    my($redis, $new) = @_;
    my $name = as_id $self->host, $channel;
    $redis->zadd("user:@{[$self->uid]}:conversations", time, $name);
    $self->_publish(add_conversation => { target => $channel });
  });
}

sub _publish {
  my ($self, $event, $data) = @_;
  my $uid = $self->uid;
  my $host = $self->host;
  my $message;

  $data->{host} = $host;
  $data->{timestamp} ||= time;
  $data->{event} = $event;
  $data->{uuid} ||= Mojo::Util::md5_sum($data->{timestamp} .$$); # not really an uuid
  $message = $JSON->encode($data);

  $self->redis->publish("wirc:user:$uid:out", $message);

  if($data->{highlight}) {
    $self->redis->lpush("user:$uid:notifications", $message);
  }

  if($event eq 'wirc_notice') {
    $self->log->warn("[$uid:$host] $data->{message}");
  }
  if($data->{save}) {
    if ($data->{target}) {
      $self->redis->zadd("user:$uid:connection:$host:$data->{target}:msg", $data->{timestamp}, $message);
    }
    else {
      $self->redis->zadd("user:$uid:connection:$host:msg", $data->{timestamp}, $message);
    }
  }
}

sub DESTROY {
  warn "DESTROY $_[0]->{path}\n" if DEBUG;
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
