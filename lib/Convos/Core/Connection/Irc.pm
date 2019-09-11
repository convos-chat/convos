package Convos::Core::Connection::Irc;
use Mojo::Base 'Convos::Core::Connection';

no warnings 'utf8';
use Convos::Util qw(next_tick DEBUG);
use Mojo::IRC::UA;
use Mojo::JSON;
use Parse::IRC ();
use Time::HiRes 'time';

use constant MAX_BULK_MESSAGE_SIZE => $ENV{CONVOS_MAX_BULK_MESSAGE_SIZE} || 3;
use constant ROOMS_REPLY_TIMEOUT   => $ENV{CONVOS_ROOMS_REPLY_TIMEOUT}   || 120;
use constant STEAL_NICK_INTERVAL   => $ENV{CONVOS_STEAL_NICK_INTERVAL}   || 60;

require Convos;

my %IRC_PROXY_METHOD = (
  ctcp_ping         => 'ctcp_ping',
  ctcp_time         => 'ctcp_time',
  ctcp_version      => 'ctcp_version',
  err_nicknameinuse => 'err_nicknameinuse',
  nick              => 'irc_nick',
  ping              => 'irc_ping',
  rpl_isupport      => 'irc_rpl_isupport',
  rpl_welcome       => 'irc_rpl_welcome',
);

has _irc => sub {
  my $self = shift;
  my $irc  = Mojo::IRC::UA->new(debug_key => join ':', $self->user->email, $self->name);

  Scalar::Util::weaken($self);
  $irc->name("Convos v$Convos::VERSION");
  $irc->parser(Parse::IRC->new(ctcp => 1));
  $irc->unsubscribe('message');
  $irc->on(close => sub { $self and $self->_event_close($_[0]) });
  $irc->on(error => sub { $self and $self->_event_error({params => [$_[1]]}) });
  $irc->on(
    message => sub {
      my ($irc, $msg) = @_;
      my $method = "_event_$msg->{event}";
      my $proxy  = $IRC_PROXY_METHOD{$msg->{event}};
      $self->_irc->$proxy($msg)   if $proxy;
      $self->_debug("$method()")  if DEBUG > 1;
      return $self->$method($msg) if $self->can($method);
      return $self->_fallback($msg) unless $msg->{look_for};    # maybe handled by Mojo::IRC::UA
    }
  );

  return $self->_setup_irc($irc);                               # make sure irc nick is correct
};

sub connect {
  my ($self, $cb) = @_;
  return $self->_maybe_reconnect($cb) if $self->state eq 'connected';

  delete $self->{disconnect};
  $self->_setup_irc;
  $self->_debug('connect(%s) Connecting...', $self->_irc->server) if DEBUG;
  $self->emit(state => frozen => $_->frozen('Not connected.')->TO_JSON)
    for grep { !$_->frozen } @{$self->dialogs};
  $self->{steal_nick_tid} //= $self->_steal_nick;

  Mojo::IOLoop->delay(
    sub { $self->_irc->connect(shift->begin) },
    sub {
      my ($delay, $err) = @_;

      $self->_debug('connect(%s) == %s', $self->_irc->server, $err || 'Success') if DEBUG or $err;
      $self->_notice($err) if $err;

      if ($self->_irc->tls and ($err =~ /IO::Socket::SSL/ or $err =~ /SSL.*HELLO/)) {
        $self->url->query->param(tls => 0);
        $self->save(sub { });
        $self->user->core->connect($self, $cb);    # let's queue up to make irc admins happy
      }
      elsif ($err) {
        $self->state(disconnected => $err)->$cb($err);
      }
      else {
        $self->{delayed} = 0;
        $self->{myinfo} ||= {};
        $self->state(connected => "Connected to @{[$self->_irc->server]}.")->$cb('');
      }
    }
  );

  return $self;
}

sub disconnect {
  my ($self, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->{disconnect} = 1;
  $self->_proxy(
    disconnect => sub {
      $self->emit(state => frozen => $_->frozen('Not connected.')->TO_JSON)
        for grep { !$_->frozen } @{$self->dialogs};
      $self->state('disconnected')->$cb($_[1] || '');
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

sub participants {
  my ($self, $name, $cb) = @_;

  $self->_proxy(
    channel_users => $name => sub {
      my ($self, $err, $res) = @_;
      my @list = $err ? () : map { +{%{$res->{$_}}, name => $_} } keys %$res;
      $self->$cb($err, {participants => \@list});
    }
  );
}

sub send {
  my ($self, $target, $message, $cb) = @_;

  $target  //= '';
  $message //= '';
  $message =~ s![\x00-\x09\x0b-\x1f]!!g;    # remove invalid characters
  $message = Mojo::Util::trim($message);    # required for kick, mode, ...

  $message =~ s!^/([A-Za-z]+)\s*!! or return $self->_send($target, $message, $cb);
  my $cmd = uc $1;

  return $self->_send($target, "\x{1}ACTION $message\x{1}", $cb) if $cmd eq 'ME';
  return $self->_send($target, $message, $cb) if $cmd eq 'SAY';
  return $self->_send(split(/\s+/, $message, 2), $cb) if $cmd eq 'MSG';
  return $self->wanted_state(connected    => $cb) if $cmd eq 'CONNECT';
  return $self->wanted_state(disconnected => $cb) if $cmd eq 'DISCONNECT';
  return $self->_is_online($message, $cb) if $cmd eq 'ISON';
  return $self->_join_dialog($message, $cb) if $cmd eq 'JOIN';
  return $self->_query_dialog($message, $cb) if $cmd eq 'QUERY';
  return $self->_kick($target, $message, $cb) if $cmd eq 'KICK';
  return $self->_mode($target, $message, $cb) if $cmd eq 'MODE';
  return $self->participants($target, $cb) if $cmd eq 'NAMES';
  return $self->nick($message, $cb) if $cmd eq 'NICK';
  return $self->_part_dialog($message || $target, $cb) if $cmd eq 'CLOSE' or $cmd eq 'PART';
  return $self->_rooms($message, $cb) if $cmd eq 'LIST';
  return $self->_topic($target, $message, $cb) if $cmd eq 'TOPIC';
  return $self->_proxy(whois => $message, $cb) if $cmd eq 'WHOIS';
  return $self->_proxy(write => "$cmd $message", sub { $self->$cb($_[1], {}); });
}

sub _event_close {
  my ($self, $irc) = @_;
  my $state = delete $self->{disconnect} ? 'disconnected' : 'queued';
  $self->state($state, sprintf 'You [%s@%s] have quit.',
    $irc->nick, $irc->real_host || $self->url->host);
  delete $self->{_irc};
  Scalar::Util::weaken($self);
  Mojo::IOLoop->timer(
    ++$self->{delayed} < 60 ? $self->{delayed} : 60,
    sub {
      $self->user->core->connect($self) if $self and $self->state eq 'queued';
    }
  );
}

# Unhandled/unexpected error
sub _event_error {
  my ($self, $msg) = @_;
  $self->_notice(join ' ', @{$msg->{params}});
}

sub _event_rpl_ison {
  my ($self, $msg) = @_;
  my $wait_for = $self->{wait_for}{ison} || {};

  # is online
  for my $dialog_id (map {lc} split /\s+/, +($msg->{params}[1] || '')) {
    delete $wait_for->{$dialog_id};
    my $dialog = $self->get_dialog($dialog_id) or next;
    $self->emit(state => frozen => $dialog->frozen('')->TO_JSON);
  }

  # offline, as far as we can tell
  for my $dialog_id (keys %$wait_for) {
    my $dialog = $self->get_dialog(lc $dialog_id) or next;
    delete $wait_for->{$dialog_id} unless --$wait_for->{$dialog_id};
    $self->emit(state => frozen => $dialog->frozen('User is offline.')->TO_JSON);
  }
}

sub _fallback {
  my ($self, $msg) = @_;

  return if grep { $msg->{command} eq $_ } qw(PONG);
  shift @{$msg->{params}} if $self->nick eq $msg->{params}[0];

  $self->emit(
    message => $self->messages,
    {
      from      => $msg->{prefix} ? +(IRC::Utils::parse_user($msg->{prefix}))[0] : $self->id,
      highlight => Mojo::JSON->false,
      message   => join(' ', @{$msg->{params}}),
      ts        => time,
      type      => 'notice',
    }
  );
}

sub _is_current_nick { lc $_[0]->_irc->nick eq lc $_[1] }

sub _is_online {
  my ($self, $dialog_id, $cb) = @_;
  $self->{wait_for}{ison}{$dialog_id}++;
  return $self->_proxy(write => "ISON $dialog_id", sub { $self->$cb($_[1], {}); });
}

sub _join_dialog {
  my $cb = pop;
  my ($self, $command) = @_;
  my ($name, $password) = (split(/\s/, ($command || ''), 2), '', '');

  Mojo::IOLoop->delay(
    sub { $self->_query_dialog($name, shift->begin) },
    sub {
      my ($delay, $err, $dialog) = @_;
      return $self->$cb($err, $dialog) if $err;
      $delay->pass($dialog);
      $self->_proxy(join_channel => $command, $delay->begin) if $dialog->frozen;
    },
    sub {
      my ($delay, $dialog, $err, $res) = @_;

      $err = 'Password protected' if $err =~ /\+k\b/;
      $res->{name} //= $name;

      unless ($self->get_dialog($res->{name})) {
        $self->remove_dialog($name);
        $dialog = $self->dialog({name => $res->{name}});
      }

      $dialog->name($res->{name}) if length $res->{name};
      $dialog->frozen($err || '')->password($password // '')->topic($res->{topic} // '');
      $self->save(sub { })->$cb($err, $dialog);
    },
  );

  return $self;
}

sub _query_dialog {
  my ($self, $name, $cb) = @_;

  # Invalid input
  return next_tick $self, $cb, 'Command missing arguments.', undef unless $name and $name =~ /\S/;
  ($name) = split /\s/, $name, 2;

  # Already in the dialog
  my $dialog = $self->get_dialog($name);
  return next_tick $self, $cb, '', $dialog if $dialog and !$dialog->frozen;

  # New dialog
  $dialog ||= $self->dialog({name => $name});
  $dialog->frozen('Not active in this room.') if !$dialog->is_private and !$dialog->frozen;
  return next_tick $self, $cb, '', $dialog;
}

sub _kick {
  my ($self, $target, $command, $cb) = @_;
  my ($nick, $reason) = split /\s/, $command, 2;

  return $self->_proxy(kick => "$target $nick :$reason", sub { $self->$cb(@_[1, 2]) });
}

sub _maybe_reconnect {
  my ($self, $cb) = @_;
  my $irc = $self->_irc;

  if ($self->url->host_port eq $irc->server) {
    $self->_debug("connect(%s) Connected", $irc->server) if DEBUG;
    return next_tick $self, $cb, '';
  }
  else {
    $self->_debug("connect(%s) Reconnect", $irc->server) if DEBUG;
    return $self->disconnect(sub { shift->connect($cb) });
  }
}

sub _mode {
  my ($self, $target, $mode, $cb) = @_;

  if ($target) {
    $mode = "$target $mode" if $mode =~ /^[+-]\S+\s+\S/;    # /mode #channel +o superman
    $mode = "$target $mode" if $mode =~ /^[+-][bs]\s*$/;    # /mode #channel -s
    $mode = "$target $mode" if $mode =~ /^[eIO]\s*$/;       # /mode #channel I
  }

  return $self->_proxy(mode => $mode, sub { $self->$cb(@_[1, 2]) });
}

sub _notice {
  my ($self, $message) = (shift, shift);
  $self->emit(
    message => $self->messages,
    {from => $self->id, type => 'notice', @_, message => $message, ts => time}
  );
}

sub _part_dialog {
  my ($self, $name, $cb) = @_;
  return next_tick $self, $cb, 'Command missing arguments.', undef unless $name and $name =~ /\S/;

  my $dialog = $self->get_dialog($name);
  return $self->_remove_dialog($name)->save($cb) if $dialog and $dialog->is_private;
  return $self->_remove_dialog($name)->save($cb) if $self->state eq 'disconnected';
  return $self->_proxy(
    part_channel => $name,
    sub {
      my ($irc, $err) = @_;
      $self->_remove_dialog($name)->save($cb);
    }
  );
}

sub _proxy {
  my ($self, $method) = (shift, shift);
  $self->_irc->$method(@_);
  $self;
}

sub _remove_dialog {
  my ($self, $name) = @_;
  my $dialog = $self->remove_dialog($name);
  $self->emit(state => part => {dialog_id => lc $name, nick => $self->_irc->nick});
  return $self;
}

sub _room_store {
  my $self = shift;
  state $cache = {};    # Rooms are shared between users
  return $cache->{$self->url->host} ||= {rooms => {}, done => Mojo::JSON->false};
}

sub _rooms {
  my ($self, $extra, $cb) = @_;

  if ($extra =~ m!/(\W?[\w-]+)/(\S*)!) {

    # Search for a specific channel - only works for cached channels
    # IMPORTANT! Make sure the filter cannot execute code inside the regex!
    my ($filter, $re_modifiers, $by, @by_name, @by_topic) = ($1, $2);
    my $store = $self->_room_store;

    $re_modifiers = 'i' unless $re_modifiers;
    $by           = $re_modifiers =~ s!([nt])!! ? $1 : 'nt';    # name or topic
    $filter       = qr{(?$re_modifiers:$filter)} if $filter;    # (?i:foo_bar)

    for my $room (sort { $a->{name} cmp $b->{name} } values %{$store->{rooms}}) {
      push @by_name,  $room and next if $room->{name} =~ $filter;
      push @by_topic, $room and next if $room->{topic} =~ $filter;
    }

    return next_tick $self, $cb, '',
      {
      done    => $store->{done},
      dialogs => [$by =~ /n/ ? @by_name : (), $by =~ /t/ ? @by_topic : ()]
      };
  }
  elsif ($extra =~ m!\S!) {
    return next_tick $self, $cb => 'Invalid argument.', {};
  }
  else {
    my $waiting = {cb => $cb};
    Mojo::IOLoop->timer(ROOMS_REPLY_TIMEOUT,
      sub { $self->$cb('Timeout!', {}) unless $waiting->{done}++ });
    push @{$self->{event_rpl_listend_cb}}, $waiting;
    $self->_irc->write('LIST');
  }
}

sub _send {
  my $cb = pop;
  my ($self, $target, $message) = @_;
  my $msg = $message;

  if (!$target) {    # err_norecipient and err_notexttosend
    return next_tick $self, $cb => 'Cannot send without target.';
  }
  elsif ($target =~ /\s/) {
    return next_tick $self, $cb => 'Cannot send message to target with spaces.';
  }

  my @messages = split /\r?\n/, ($message // '');
  return next_tick $self, $cb => 'Cannot send empty message.' unless @messages;

  for (@messages) {
    $_ = $self->_irc->parser->parse(sprintf ':%s PRIVMSG %s :%s', $self->_irc->nick, $target, $_);
    return next_tick $self, $cb => 'Unable to construct PRIVMSG.' unless ref $_;
  }

  if (MAX_BULK_MESSAGE_SIZE < @messages) {
    $self->user->core->backend->emit_single(
      multiline_message => $self,
      \$message,
      sub {
        my ($backend, $err, $paste_message) = @_;
        return $self->$cb($err) if $err;
        return $self->_send($target, $paste_message, $cb);
      }
    );
    return $self;
  }

  # Seems like there is no way to know if a message is delivered
  # Instead, there might be some errors occuring if the message had issues:
  # err_cannotsendtochan, err_nosuchnick, err_notoplevel, err_toomanytargets,
  # err_wildtoplevel, irc_rpl_away

  my $cb_called = 0;
  for my $msg (@messages) {
    $self->_proxy(
      write => $msg->{raw_line},
      sub {
        my ($irc, $err) = @_;
        return $self->$cb($err) if $err and !$cb_called++;
        $msg->{prefix} = sprintf '%s!%s@%s', $irc->nick, $irc->user, $irc->server;
        $msg->{event}  = lc $msg->{command};
        next_tick $self, _event_privmsg => $msg;
        $self->$cb('') unless $cb_called++;
      }
    );
  }

  return $self;
}

sub _setup_irc {
  my $self     = shift;
  my $irc      = shift || $self->_irc;
  my $url      = $self->url;
  my $userinfo = $self->_userinfo;
  my $nick     = $url->query->param('nick');
  my $tls      = $url->query->param('tls') // 1;
  my $verify   = $url->query->param('tls_verify') // $tls;

  unless ($nick) {
    $nick = $self->user->email =~ /^([^@]+)/ ? $1 : 'convos_user';
    $nick =~ s!\W!_!g;
    $url->query->param(nick => $nick);
  }

  $irc->server($url->host_port || 'localhost:6667');
  $irc->nick($nick);
  $irc->user($userinfo->[0]);
  $irc->pass($userinfo->[1]);
  $irc->tls($tls ? {insecure => !$verify} : undef);
}

sub _steal_nick {
  my $self = shift;
  my $tid;

  Scalar::Util::weaken($self);
  $tid = $self->_irc->ioloop->recurring(
    STEAL_NICK_INTERVAL,
    sub {
      return shift->remove($tid) unless $self;
      return unless my $nick = $self->url->query->param('nick');
      return $self->_irc->write("NICK $nick") if $self->_irc->nick ne $nick;
    }
  );

  return $tid;
}

sub _topic {
  my ($self, $target, $topic, $cb) = @_;
  my @args = ($target, defined $topic ? ($topic) : ());
  $self->_proxy(channel_topic => @args, $cb);
}

sub _event_err_cannotsendtochan {
  my ($self, $msg) = @_;
  $self->_notice("Cannot send to channel $msg->{params}[1].");
}

sub _event_err_erroneusnickname {
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1] || 'unknown';
  $self->_notice("Invalid nickname $nick.");
}

sub _event_err_nicknameinuse {
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->_notice("Nickname $nick is already in use.") unless $self->{err_nicknameinuse}{$nick}++;
}

sub _event_err_unknowncommand {
  my ($self, $msg) = @_;
  $self->_notice('Unknown command');
}

sub _event_join {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $channel = $msg->{params}[0];

  if ($self->_is_current_nick($nick)) {
    my $dialog = $self->dialog({name => $channel, frozen => ''});
    $self->emit(state => frozen => $dialog->TO_JSON);
  }
  elsif (my $dialog = $self->get_dialog($channel)) {
    $self->emit(state => join => {dialog_id => $dialog->id, nick => $nick});
  }
}

sub _event_kick {
  my ($self, $msg) = @_;
  my ($kicker) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog   = $self->dialog({name => $msg->{params}[0]});
  my $nick     = $msg->{params}[1];
  my $reason   = $msg->{params}[2] || '';

  $self->emit(state => part =>
      {dialog_id => $dialog->id, kicker => $kicker, nick => $nick, message => $reason});
}

# :superman!superman@i.love.debian.org MODE superman :+i
# :superman!superman@i.love.debian.org MODE #convos superman :+o
# :hybrid8.debian.local MODE #no_such_room +nt
sub _event_mode {
  my ($self, $msg) = @_;
  my ($from) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->get_dialog({name => $msg->{params}[0]}) or return;
  my $mode = $msg->{params}[1] || '';
  my $nick = $msg->{params}[2] || '';

  $self->emit(
    state => mode => {dialog_id => $dialog->id, from => $from, mode => $mode, nick => $nick});
}

# :Superman12923!superman@i.love.debian.org NICK :Supermanx
sub _event_nick {
  my ($self, $msg) = @_;
  my ($old_nick)  = IRC::Utils::parse_user($msg->{prefix});
  my $new_nick    = $msg->{params}[0];
  my $wanted_nick = $self->url->query->param('nick');

  if ($wanted_nick and $wanted_nick eq $new_nick) {
    delete $self->{err_nicknameinuse};    # allow warning on next nick change
  }

  if ($self->_is_current_nick($new_nick)) {
    $self->{myinfo}{nick} = $new_nick;
    $self->emit(state => me => $self->{myinfo});
  }
  else {
    $self->emit(state => nick_change => {new_nick => $new_nick, old_nick => $old_nick});
  }
}

sub _event_part {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->get_dialog($msg->{params}[0]);
  my $reason = $msg->{params}[1] || '';

  if ($dialog and !$self->_is_current_nick($nick)) {
    $self->emit(state => part => {dialog_id => $dialog->id, nick => $nick, message => $reason});
  }
}

sub _event_notice {
  my ($self, $msg) = @_;
  $self->_irc->irc_notice($msg);
  $self->_event_privmsg($msg);
}

sub _event_privmsg {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my ($from, $highlight, $target);

  # http://www.mirc.com/colors.html
  $msg->{params}[1] =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $msg->{params}[1] =~ s/[\x00-\x1f]//g;

  if ($user) {
    $target = $self->_is_current_nick($msg->{params}[0]) ? $nick : $msg->{params}[0];
    $target = $self->get_dialog($target) || $self->dialog({name => $target});
    $from   = $nick;
  }

  $target ||= $self->messages;
  $from   ||= $self->id;

  unless ($self->_is_current_nick($nick)) {
    $highlight = grep { $msg->{params}[1] =~ /\b\Q$_\E\b/i } $self->_irc->nick,
      @{$self->user->highlight_keywords};
  }

  $target->last_active(Mojo::Date->new->to_datetime);

  # server message or message without a dialog
  $self->emit(
    message => $target,
    {
      from      => $from,
      highlight => $highlight ? Mojo::JSON->true : Mojo::JSON->false,
      message   => $msg->{params}[1],
      ts        => time,
      type      => $msg->{event} =~ /privmsg/i ? 'private'
      : $msg->{event} =~ /action/i ? 'action'
      :                              'notice',
    }
  );
}

sub _event_quit {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});

  $self->emit(state => quit => {nick => $nick, message => join ' ', @{$msg->{params}}});
}

sub _event_rpl_list {
  my ($self, $msg) = @_;
  my $store = $self->_room_store;
  my $room
    = {name => $msg->{params}[1], n_users => 0 + $msg->{params}[2], topic => $msg->{params}[3]};

  $room->{dialog_id}  = lc $room->{name};
  $room->{is_private} = 0;
  $room->{topic} =~ s!^(\[\+[a-z]+\])\s?!!;    # remove mode from topic, such as [+nt]

  $store->{rooms}{$room->{name}} = $room;
  $self->emit(state => dialog_info => {%$room, done => Mojo::JSON->false});
}

sub _event_rpl_listend {
  my ($self, $msg) = @_;
  my $store        = $self->_room_store;
  my $waiting_list = delete $self->{event_rpl_listend_cb} || [];

  $store->{done} = Mojo::JSON->true;
  $self->emit(state => dialog_info => {done => $store->{done}});

  for my $waiting (@$waiting_list) {
    my $cb = $waiting->{cb};
    $self->$cb('', {done => $store->{done}}) unless $waiting->{done}++;
  }
}

sub _event_rpl_liststart {
  my ($self, $msg) = @_;
  $self->_room_store->{done} = Mojo::JSON->false;
}

# :hybrid8.debian.local 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh
sub _event_rpl_myinfo {
  my ($self, $msg) = @_;
  my @keys = qw(nick real_host version available_user_modes available_channel_modes);
  my $i    = 0;

  $self->{myinfo}{$_} = $msg->{params}[$i++] // '' for @keys;
  $self->emit(state => me => $self->{myinfo});
}

# :hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
sub _event_rpl_welcome {
  my ($self, $msg) = @_;
  my ($write, @commands);

  push @commands, map  { $_->is_private ? "/ison $_->{name}" : $_ } @{$self->dialogs};
  push @commands, grep {/\S/} @{$self->on_connect_commands};

  $self->_notice($msg->{params}[1]);    # Welcome to the debian Internet Relay Chat Network superman
  $self->{myinfo}{nick} = $msg->{params}[0];
  $self->emit(state => me => $self->{myinfo});

  Scalar::Util::weaken($self);
  $write = sub {
    my $cmd = $self && shift @commands || return;
    return $self->_join_dialog(join(' ', $cmd->name, $cmd->password), $write) if ref $cmd;
    return $self->send('', $cmd, $write);
  };

  next_tick $self, $write;
}

# :superman!superman@i.love.debian.org TOPIC #convos :cool
sub _event_topic {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $dialog = $self->dialog({name => $msg->{params}[0], topic => $msg->{params}[1]});

  $self->emit(state => topic => $dialog->TO_JSON)->save(sub { });

  return $self->_notice("Topic unset by $nick") unless $dialog->topic;
  return $self->_notice("$nick changed the topic to: " . $dialog->topic);
}

sub DESTROY {
  my $self   = shift;
  my $ioloop = $self->{_irc}{ioloop} or return;
  my $tid;
  $ioloop->remove($tid) if $tid = $self->{steal_nick_tid};
}

sub TO_JSON {
  my $self = shift;
  my $json = $self->SUPER::TO_JSON(@_);
  $json->{me} = $self->{myinfo} || {};
  $json;
}

*_event_ctcp_action = \*_event_privmsg;

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

=head2 nick

  $self = $self->nick($nick => sub { my ($self, $err) = @_; });
  $self = $self->nick(sub { my ($self, $err, $nick) = @_; });
  $nick = $self->nick;

Used to set or get the nick for this connection. Setting this nick will change
L</nick> and try to change the nick on server if connected. Getting this nick
will retrieve the active nick on server if connected and fall back to returning
L</nick>.

=head2 participants

See L<Convos::Core::Connection/participants>.

=head2 send

See L<Convos::Core::Connection/send>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
