package Convos::Core::Connection::Irc;
use Mojo::Base 'Convos::Core::Connection';

no warnings 'utf8';
use Convos::Util 'DEBUG';
use Mojo::IRC::UA;
use Parse::IRC ();
use Time::HiRes 'time';

use constant STEAL_NICK_INTERVAL => $ENV{CONVOS_STEAL_NICK_INTERVAL} || 60;
use constant ROOM_CACHE_TIMER    => $ENV{CONVOS_ROOM_CACHE_TIMER}    || 60;

require Convos;

# allow jumping between event names in your editor by matching whole words
# "_event irc_topic => sub {}" vs "sub _event_irc_topic"
sub _event { Mojo::Util::monkey_patch(__PACKAGE__, "_event_$_[0]" => $_[1]); }

my $PARSER = Parse::IRC->new(ctcp => 1);

has _irc => sub {
  my $self = shift;
  my $url  = $self->url;
  my $user = $self->_userinfo->[0];
  my $irc  = Mojo::IRC::UA->new(debug_key => join ':', $user, $self->name);
  my $nick;

  unless ($nick = $url->query->param('nick')) {
    $nick = $user;
    $nick =~ s![^\w_]!_!g;
    $url->query->param(nick => $nick);
  }

  $irc->name("Convos v$Convos::VERSION");
  $irc->nick($nick);
  $irc->user($user);
  $irc->parser(Parse::IRC->new(ctcp => 1));

  Scalar::Util::weaken($self);
  $irc->register_default_event_handlers;
  $irc->on(close => sub { $self and $self->_event_irc_close });
  $irc->on(error => sub { $self and $self->_event_irc_error({params => [$_[1]]}) });

  for my $event (qw(ctcp_action irc_notice irc_privmsg)) {
    $irc->on($event => sub { $self->_irc_message($event => $_[1]) });
  }

  for my $event (
    'err_bannedfromchan', 'err_cannotsendtochan', 'err_nicknameinuse', 'err_nosuchnick',
    'irc_error',          'irc_join',             'irc_kick',          'irc_mode',
    'irc_nick',           'irc_part',             'irc_quit',          'irc_rpl_away',
    'irc_rpl_endofmotd',  'irc_rpl_endofnames',   'irc_rpl_motd',      'irc_rpl_motdstart',
    'irc_rpl_myinfo',     'irc_rpl_namreply',     'irc_rpl_topic',     'irc_rpl_topicwhotime',
    'irc_rpl_welcome',    'irc_rpl_yourhost',     'irc_topic',
    )
  {
    my $method = "_event_$event";
    $irc->on($event => sub { $self->$method($_[1]) unless $_[1]->{handled}++ });
  }

  $irc;
};

sub connect {
  my ($self, $cb) = @_;
  my $irc      = $self->_irc;
  my $userinfo = $self->_userinfo;
  my $url      = $self->url;
  my $tls      = $url->query->param('tls') // 1;

  $irc->user($userinfo->[0]);
  $irc->pass($userinfo->[1]);
  $irc->server($url->host_port) unless $irc->server;
  $irc->tls($tls ? {} : undef);

  warn "[@{[$self->user->email]}/@{[$self->id]}] connect($irc->{server})\n" if DEBUG;

  unless ($irc->server) {
    return $self->_next_tick($cb => 'Invalid URL: hostname is not defined.');
  }

  delete $self->{disconnect};
  Scalar::Util::weaken($self);
  $self->state('connecting');
  $self->{steal_nick_tid}
    ||= $irc->ioloop->recurring(STEAL_NICK_INTERVAL, sub { $self->_steal_nick });

  for my $dialog (@{$self->dialogs}) {
    $dialog->frozen('Not fully connected.');
  }

  return $self->_next_tick(
    sub {
      $irc->connect(
        sub {
          my ($irc, $err) = @_;

          if ($tls and ($err =~ /IO::Socket::SSL/ or $err =~ /SSL.*HELLO/)) {
            $url->query->param(tls => 0);
            $self->save(sub { });    # save updated URL
            $self->connect($cb);
          }
          elsif ($err) {
            $self->state(disconnected => $err)->$cb($err);
          }
          else {
            $self->{myinfo} ||= {};
            $self->state(connected => "Connected to $irc->{server}.")->$cb('');
          }
        }
      );
    }
  );
}

sub disconnect {
  my ($self, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->{disconnect} = 1;
  $self->_proxy(disconnect => sub { $self->state('disconnected')->$cb($_[1] || '') });
}

sub join_dialog {
  my $cb   = pop;
  my $self = shift;
  my ($name, $password) = split /\s/, shift, 2;
  my $dialog = $self->dialog({active => 1, name => $name, password => $password // ''});

  return $self->_next_tick($cb, '', $dialog) if %{$dialog->users};
  Scalar::Util::weaken($self);
  return $self->_proxy(
    join_channel => $name,
    sub {
      my ($irc, $err) = @_;
      $self->remove_dialog($name) if $err;
      $self->$cb($err, $dialog);
    }
  );
}

sub nick {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, @nick) = @_;    # @nick will be empty list on "get"

  return $self->_irc->nick(@nick) unless $cb;
  Scalar::Util::weaken($self);
  $self->url->query->param(nick => $nick[0]) if @nick;
  $self->_irc->nick(@nick, sub { shift; $self->$cb(@_) });
  $self;
}

sub part_dialog {
  my ($self, $name, $cb) = @_;

  return $self->_proxy(
    part_channel => $name,
    sub {
      my ($irc, $err) = @_;
      $self->remove_dialog($name) unless $err;
      $self->$cb($err);
    }
  );
}

sub rooms {
  my ($self, $cb) = @_;
  my $host = $self->url->host;

  state $cache = {};    # room list is shared between all connections
  return $self->_next_tick($cb, '', $cache->{$host}) if $cache->{$host};

  Scalar::Util::weaken($self);
  return $self->_proxy(
    channels => sub {
      my ($irc, $err, $map) = @_;
      $cache->{$host} = [map { my $c = $map->{$_}; $c->{name} = $_; $c } keys %$map];
      Mojo::IOLoop->timer(ROOM_CACHE_TIMER, sub { delete $cache->{$host} });
      $self->$cb($err, $cache->{$host});
    },
  );
}

sub send {
  my ($self, $target, $message, $cb) = @_;

  $message //= '';
  if ($message =~ s!^/!!) {
    my ($cmd, $args) = split /\s/, $message, 2;
    return $self->_next_tick($cb => 'Invalid IRC command.') unless $cmd =~ /^[A-Za-z]+$/;

    $cmd = uc $cmd;
    return $self->_proxy(channel_users => $target, $cb) if $cmd eq 'NAMES';
    return $self->_send($target, "\x{1}ACTION $args\x{1}", $cb) if $cmd eq 'ME';
    return $self->_send($target, $args, $cb) if $cmd eq 'SAY';
    return $self->_send(split(/\s+/, $args, 2), $cb) if $cmd eq 'MSG';
    return $self->connect($cb)    if $cmd eq 'CONNECT';
    return $self->disconnect($cb) if $cmd eq 'DISCONNECT';
    return $self->join_dialog($args, $cb) if $cmd eq 'JOIN';
    return $self->nick($args, $cb) if $cmd eq 'NICK';
    return $self->part_dialog($args || $target, $cb) if $cmd eq 'CLOSE';
    return $self->part_dialog($args || $target, $cb) if $cmd eq 'PART';
    return $self->topic($target, $args ? ($args) : (), $cb) if $cmd eq 'TOPIC';
    return $self->whois($args, $cb) if $cmd eq 'WHOIS';
    return $self->_next_tick($cb => 'Unknown IRC command.');
  }

  return $self->_send($target, $message, $cb);
}

sub topic {
  my $cb   = pop;
  my $self = shift;
  Scalar::Util::weaken($self);
  $self->_proxy(channel_topic => @_, sub { shift; $self->$cb(@_); });
}

sub whois {
  my ($self, $target, $cb) = @_;
  return $self->tap($cb, "Cannot retrieve whois without target.", {})
    unless $target;    # err_nonicknamegiven
  Scalar::Util::weaken($self);
  $self->_proxy(whois => $target, sub { shift; $self->$cb(@_); });
}

sub _event_irc_close {
  my ($self) = @_;
  $self->state(
    delete $self->{disconnect} ? 'disconnected' : 'connecting',
    sprintf 'You [%s@%s] have quit.',
    $self->_irc->nick, $self->_irc->real_host || $self->url->host
  );
  delete $self->{_irc};
}

# Unhandled/unexpected error
sub _event_irc_error {
  my ($self, $msg) = @_;
  $self->_notice(join ' ', @{$msg->{params}});
}

sub _irc_message {
  my ($self, $event, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $target = $msg->{params}[0];

  if ($user) {
    my $current_nick = $self->_irc->nick;
    my $is_private   = $self->_is_current_nick($target);

    $self->emit(
      message => $self->dialog({name => $is_private ? $nick : $target}),
      {
        from    => $nick,
        message => $msg->{params}[1],
        ts      => time,
        type    => $event =~ /privmsg/ ? 'private' : $event =~ /action/ ? 'action' : 'notice',
      }
    );
  }
  else {    # server message
    $self->emit(
      message => $self,
      {
        from => $msg->{prefix} // $self->_irc->server,
        message => $msg->{params}[1],
        ts      => time,
        type    => $event eq 'irc_privmsg' ? 'private' : 'notice',
      }
    );
  }
}

sub _is_current_nick { lc $_[0]->_irc->nick eq lc $_[1] }

sub _notice {
  my ($self, $message) = (shift, shift);
  $self->emit(
    message => $self,
    {from => $self->url->host, type => 'notice', @_, message => $message, ts => time}
  );
}

sub _proxy {
  my ($self, $method) = (shift, shift);
  $self->_irc->$method(@_);
  $self;
}

sub _send {
  my ($self, $target, $message, $cb) = @_;
  my $msg = $message;

  if (!$target) {    # err_norecipient and err_notexttosend
    return $self->_next_tick($cb => 'Cannot send without target.');
  }
  elsif ($target =~ /\s/) {
    return $self->_next_tick($cb => 'Cannot send message to target with spaces.');
  }
  elsif (length $message) {
    $msg = $PARSER->parse(sprintf ':%s PRIVMSG %s :%s', $self->_irc->nick, $target, $message);
    return $self->_next_tick($cb => 'Unable to construct PRIVMSG.') unless ref $msg;
  }
  else {
    return $self->_next_tick($cb => 'Cannot send empty message.');
  }

  # Seems like there is no way to know if a message is delivered
  # Instead, there might be some errors occuring if the message had issues:
  # err_cannotsendtochan, err_nosuchnick, err_notoplevel, err_toomanytargets,
  # err_wildtoplevel, irc_rpl_away

  Scalar::Util::weaken($self);
  return $self->_proxy(
    write => $msg->{raw_line},
    sub {
      my ($irc, $err) = @_;
      return $self->$cb($err) if $err;
      $msg->{prefix} = sprintf '%s!%s@%s', $irc->nick, $irc->user, $irc->server;
      $self->_irc_message(lc($msg->{command}) => $msg);
      $self->$cb('');
    }
  );
}

sub _steal_nick {
  my $self = shift;
  my $nick = $self->url->query->param('nick');
  $self->_irc->write("NICK $nick") if $nick and $self->_irc->nick ne $nick;
}

# :hybrid8.debian.local 474 superman #convos :Cannot join channel (+b)
_event err_bannedfromchan => sub {    # TODO
  my ($self,    $msg)    = @_;
  my ($channel, $reason) = @{$msg->{params}};
  my $nick   = $self->_irc->nick;
  my $dialog = $self->get_dialog($channel);

  $dialog->frozen($reason =~ s/channel/channel $channel/i ? $reason : "$reason $channel")
    if $dialog;
  $self->_notice("$nick is banned from $channel [$reason]");
};

_event err_cannotsendtochan => sub {
  my ($self, $msg) = @_;
  $self->_notice("Cannot send to channel $msg->{params}[1].");
};

_event err_nicknameinuse => sub {    # TODO
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->_notice(qq(Nickname $nick is already in use.)) unless $self->{err_nicknameinuse}{$nick}++;
};

# :hybrid8.debian.local 401 Superman #no_such_channel_ :No such nick/channel
_event err_nosuchnick => sub {
  my ($self, $msg) = @_;

  if (my $dialog = $self->get_dialog($msg->{params}[1])) {
    $self->emit(
      message => $dialog,
      {
        from    => $self->url->host,
        message => 'No such nick or channel.',
        ts      => time,
        type    => 'notice'
      }
    );
  }

  $self->_notice("No such nick or channel $msg->{params}[1].");
};

# :superman!superman@i.love.debian.org JOIN :#convos
_event irc_join => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->dialog({frozen => '', name => $msg->{params}[0]});

  $dialog->users->{lc($nick)} ||= {host => $host, name => $nick, user => $user};
  $self->emit(users => $dialog, {join => lc($nick)});
};

# TODO
_event irc_kick => sub {
  my ($self, $msg) = @_;
  my ($kicker) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->dialog({name => $msg->{params}[0]});
  my $nick   = $msg->{params}[1];
  my $reason = $msg->{params}[2] || '';

  delete $dialog->users->{lc($nick)};
  $self->emit(users => $dialog, {kicker => $kicker, part => lc($nick), message => $reason});
};

# :superman!superman@i.love.debian.org MODE superman :+i
# :superman!superman@i.love.debian.org MODE #convos superman :+o
# :hybrid8.debian.local MODE #no_such_room +nt
_event irc_mode => sub {
  my ($self, $msg) = @_;    # TODO
};

# :Superman12923!superman@i.love.debian.org NICK :Supermanx
_event irc_nick => sub {
  my ($self, $msg) = @_;
  my ($old_nick)  = IRC::Utils::parse_user($msg->{prefix});
  my $old_nick_lc = lc $old_nick;
  my $new_nick    = $msg->{params}[0];
  my $wanted_nick = $self->url->query->param('nick');

  delete $self->{err_nicknameinuse}
    if $wanted_nick and $wanted_nick eq $new_nick;    # allow warning on next nick change

  if ($self->_is_current_nick($new_nick)) {
    $self->{myinfo}{nick} = $new_nick;
    $self->emit(me => $self->{myinfo});
  }

  for my $dialog (values %{$self->{dialogs}}) {
    my $info = delete $dialog->users->{$old_nick_lc} or next;
    $info->{name} = $new_nick;
    $dialog->{users}{lc($new_nick)} = $info;
    $self->emit(users => $dialog => {%$info, renamed_from => $old_nick_lc});
  }
};

_event irc_part => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->dialog({name => $msg->{params}[0]});
  my $reason = $msg->{params}[1] || '';

  # logging is the same as irssi

  if ($self->_is_current_nick($nick)) {
    $self->remove_dialog($msg->{params}[0]);
    $dialog->frozen('Parted.');
  }

  delete $dialog->users->{lc($nick)};
  $self->emit(users => $dialog => {part => lc($nick), message => $reason});
};

_event irc_quit => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $nick_lc = lc $nick;
  my $reason = $msg->{params}[1] || '';

  for my $dialog (values %{$self->{dialogs}}) {
    delete $dialog->users->{$nick_lc} or next;
    $self->emit(users => $dialog => {part => $nick_lc, message => $reason});
  }
};

_event irc_rpl_away => sub {
  my ($self, $msg) = @_;
};

# :hybrid8.debian.local 376 superman :End of /MOTD command.
_event irc_rpl_endofmotd => sub {
  $_[0]->_notice($_[1]->{params}[1]);
};

# :hybrid8.debian.local 366 superman #convos :End of /NAMES list.
# See also _irc_rpl_namreply()
_event irc_rpl_endofnames => sub {
  my ($self, $msg) = @_;
  my $channel = $msg->{params}[1];
  my $dialog  = $self->dialog({name => $channel});
  my $users   = $dialog->users;
  my $last    = $dialog->{last_irc_rpl_endofnames} || 0;

  for my $nick (keys %$users) {
    my $info = $users->{$nick};
    next if $last <= $info->{seen};
    delete $users->{$nick};
  }

  $dialog->{last_irc_rpl_endofnames} = time;
  $self->emit(users => $dialog => {updated => Mojo::JSON->true});
};

# :hybrid8.debian.local 372 superman :too cool for school
_event irc_rpl_motd => sub {
  $_[0]->_notice($_[1]->{params}[1]);
};

# :hybrid8.debian.local 375 superman :- hybrid8.debian.local Message of the Day -
_event irc_rpl_motdstart => sub {
  $_[0]->_notice($_[1]->{params}[1]);
};

# :hybrid8.debian.local 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh
_event irc_rpl_myinfo => sub {
  my ($self, $msg) = @_;
  my @keys = qw( nick real_host version available_user_modes available_channel_modes );
  my $i    = 0;

  $self->{myinfo}{$_} = $msg->{params}[$i++] // '' for @keys;
};

# :hybrid8.debian.local 353 superman = #convos :superman @jhthorsen
# See also _irc_rpl_endofnames()
_event irc_rpl_namreply => sub {
  my ($self, $msg) = @_;
  my $users = $self->dialog({name => $msg->{params}[2]})->users;

  for my $nick (sort { lc $a cmp lc $b } split /\s+/, $msg->{params}[3]) {
    my $mode = $nick =~ s/^([@~+*])// ? $1 : '';
    my $nick_lc = lc $nick;
    $users->{$nick_lc}{mode} = $mode;
    $users->{$nick_lc}{name} = $nick;
    $users->{$nick_lc}{seen} = time;
  }
};

# :hybrid8.debian.local 332 superman #convos :test123
_event irc_rpl_topic => sub {
  my ($self, $msg) = @_;
  my $dialog = $self->dialog({name => $msg->{params}[1], topic => $msg->{params}[2]});
  $self->_notice(sprintf 'Topic for %s: %s', $dialog->name, $dialog->topic);
};

# :hybrid8.debian.local 333 superman #convos jhthorsen!jhthorsen@i.love.debian.org 1432142279
_event irc_rpl_topicwhotime => sub {
  my ($self, $msg) = @_;    # TODO
  my $dialog = $self->dialog({name => $msg->{params}[1], topic_by => $msg->{params}[2]});

  # irssi log message contains localtime(), but we already log to file with a timestamp
  $self->_notice("Topic set by $msg->{params}[2]");
};

# :hybrid8.debian.local 002 superman :Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2
_event irc_rpl_yourhost => sub {
  $_[0]->_notice($_[1]->{params}[1]);
};

# :hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
_event irc_rpl_welcome => sub {
  my ($self, $msg) = @_;

  $self->_notice($msg->{params}[1]);    # Welcome to the debian Internet Relay Chat Network superman
  $self->{myinfo}{nick} = $msg->{params}[0];
  $self->emit(me => $self->{myinfo});
  $self->join_dialog(join(' ', $_->name, $_->password), sub { })
    for grep { $_->active } @{$self->dialogs};
};

# :superman!superman@i.love.debian.org TOPIC #convos :cool
_event irc_topic => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $dialog = $self->dialog({name => $msg->{params}[0], topic => $msg->{params}[1]});

  return $self->_notice("Topic unset by $nick") unless $dialog->topic;
  return $self->_notice("$nick changed the topic to: " . $dialog->topic);
};

sub DESTROY {
  my $self = shift;
  my $ioloop = $self->{_irc}{ioloop} or return;
  my $tid;
  $ioloop->remove($tid) if $tid = $self->{steal_nick_tid};
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Connection::Irc - IRC connection for Convos

=head1 DESCRIPTION

L<Convos::Core::Connection::Irc> is a connection class for L<Convos> which
allow you to communicate over the IRC protocol.

=head1 ATTRIBUTES

L<Convos::Core::Connection::Irc> inherits all attributes from L<Convos::Core::Connection>
and implements the following new ones.

=head1 METHODS

L<Convos::Core::Connection::Irc> inherits all methods from L<Convos::Core::Connection>
and implements the following new ones.

=head2 connect

See L<Convos::Core::Connection/connect>.

=head2 disconnect

See L<Convos::Core::Connection/disconnect>.

=head2 join_dialog

See L<Convos::Core::Connection/join_dialog>.

=head2 nick

  $self = $self->nick($nick => sub { my ($self, $err) = @_; });
  $self = $self->nick(sub { my ($self, $err, $nick) = @_; });
  $nick = $self->nick;

Used to set or get the nick for this connection. Setting this nick will change
L</nick> and try to change the nick on server if connected. Getting this nick
will retrieve the active nick on server if connected and fall back to returning
L</nick>.

=head2 part_dialog

See L<Convos::Core::Connection/dialog>.

=head2 rooms

See L<Convos::Core::Connection/rooms>.

=head2 send

See L<Convos::Core::Connection/send>.

=head2 topic

See L<Convos::Core::Connection/topic>.

=head2 whois

See L<Convos::Core::Connection/whois>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
