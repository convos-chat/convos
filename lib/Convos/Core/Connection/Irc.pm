package Convos::Core::Connection::Irc;
use Mojo::Base 'Convos::Core::Connection';

no warnings 'utf8';
use Convos::Util qw(next_tick DEBUG);
use Mojo::IRC::UA;
use Mojo::JSON;
use Parse::IRC ();
use Time::HiRes 'time';

use constant STEAL_NICK_INTERVAL => $ENV{CONVOS_STEAL_NICK_INTERVAL} || 60;
use constant ROOM_CACHE_TIMER    => $ENV{CONVOS_ROOM_CACHE_TIMER}    || 60;

require Convos;

# allow jumping between event names in your editor by matching whole words
# "_event irc_topic => sub {}" vs "sub _event_irc_topic"
sub _event { Mojo::Util::monkey_patch(__PACKAGE__, "_event_$_[0]" => $_[1]); }

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

  $user =~ s![^a-z]!!gi;

  $irc->name("Convos v$Convos::VERSION");
  $irc->nick($nick);
  $irc->user($user);
  $irc->parser(Parse::IRC->new(ctcp => 1));

  Scalar::Util::weaken($self);
  $irc->register_default_event_handlers;
  $irc->on(close => sub { $self and $self->_event_irc_close($_[0]) });
  $irc->on(error => sub { $self and $self->_event_irc_error({params => [$_[1]]}) });

  for my $event (qw(ctcp_action irc_notice irc_privmsg)) {
    $irc->on($event => sub { $self->_irc_message($event => $_[1]) });
  }

  for my $event (
    qw(
    err_cannotsendtochan err_erroneusnickname err_nicknameinuse irc_error
    irc_join irc_kick irc_mode irc_nick irc_part irc_quit irc_rpl_myinfo
    irc_rpl_welcome irc_topic
    )
    )
  {
    my $method = "_event_$event";
    $irc->on($event => sub { $self->$method($_[1]) });
  }

  for my $event (
    qw(
    err_nomotd err_nosuchserver irc_rpl_yourhost irc_rpl_endofinfo
    irc_rpl_created irc_rpl_bounce irc_rpl_adminme irc_rpl_adminemail
    irc_rpl_global_users irc_rpl_isupport irc_rpl_localusers irc_rpl_statsconn
    irc_rpl_tryagain irc_rpl_endoflinks irc_rpl_endofmotd
    irc_rpl_endofstats irc_rpl_info irc_rpl_links irc_rpl_luserchannels
    irc_rpl_luserclient irc_rpl_luserme irc_rpl_luserop
    irc_rpl_luserunkown irc_rpl_motd irc_rpl_motdstart irc_rpl_servlist
    irc_rpl_servlistend irc_rpl_statscommands irc_rpl_statslinkinfo
    irc_rpl_statsoline irc_rpl_statsuptime irc_rpl_time irc_rpl_version
    )
    )
  {
    $irc->on($event => sub { $self->_irc_any($_[1]) });
  }

  return $irc;
};

sub connect {
  my ($self, $cb) = @_;
  my $irc      = $self->_irc;
  my $userinfo = $self->_userinfo;
  my $url      = $self->url;
  my $tls      = $url->query->param('tls') // 1;

  $irc->pass($userinfo->[1]);
  $irc->server($url->host_port) unless $irc->server;
  $irc->tls($tls ? {} : undef);

  warn "[@{[$self->user->email]}/@{[$self->id]}] connect($irc->{server})\n" if DEBUG;

  unless ($irc->server) {
    return next_tick $self, $cb, 'Invalid URL: hostname is not defined.';
  }

  delete $self->{disconnect};
  Scalar::Util::weaken($self);
  $self->state('queued', 'Connecting...');
  $self->{steal_nick_tid} //= $self->_steal_nick;

  for my $dialog (@{$self->dialogs}) {
    next if $dialog->is_private;    # TODO: Should private conversations be frozen as well?
    $dialog->frozen('Not connected.');
    $self->emit(state => frozen => $dialog->TO_JSON);
  }

  Mojo::IOLoop->delay(
    sub { $irc->connect(shift->begin) },
    sub {
      my ($delay, $err) = @_;
      $self->_notice($err) if $err;

      if ($tls and ($err =~ /IO::Socket::SSL/ or $err =~ /SSL.*HELLO/)) {
        $url->query->param(tls => 0);
        $self->save(sub { });
        $self->user->core->connect($self, $cb);    # let's queue up to make irc admins happy
      }
      elsif ($err) {
        $self->state(disconnected => $err)->$cb($err);
      }
      else {
        $self->{delayed} = 0;
        $self->{myinfo} ||= {};
        $self->state(connected => "Connected to $irc->{server}.")->$cb('');
      }
    }
  );

  return $self;
}

sub disconnect {
  my ($self, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->{disconnect} = 1;
  $self->_proxy(disconnect => sub { $self->state('disconnected')->$cb($_[1] || '') });
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

sub rooms {
  my ($self, $cb) = @_;
  my $host = $self->url->host;

  state $cache = {};    # room list is shared between all connections
  return next_tick $self, $cb, '', $cache->{$host} if $cache->{$host};

  Scalar::Util::weaken($self);
  return $self->_proxy(
    channels => sub {
      my ($irc, $err, $map) = @_;
      $cache->{$host} = [map { my $c = $map->{$_}; $c->{name} = $_; $c } keys %$map];
      delete $cache->{$host} unless @{$cache->{$host}};
      Mojo::IOLoop->timer(ROOM_CACHE_TIMER, sub { delete $cache->{$host} });
      $self->$cb($cache->{$host} ? $err : 'No rooms.', $cache->{$host} || []);
    },
  );
}

sub send {
  my ($self, $target, $message, $cb) = @_;

  $target  //= '';
  $message //= '';
  $message =~ s![\x00-\x1f]!!g;    # remove invalid characters
  $message = Mojo::Util::trim($message);    # required for kick, mode, ...

  $message =~ s!^/([A-Za-z]+)\s*!! or return $self->_send($target, $message, $cb);
  my $cmd = uc $1;

  return $self->_send($target, "\x{1}ACTION $message\x{1}", $cb) if $cmd eq 'ME';
  return $self->_send($target, $message, $cb) if $cmd eq 'SAY';
  return $self->_send(split(/\s+/, $message, 2), $cb) if $cmd eq 'MSG';
  return $self->connect($cb)    if $cmd eq 'CONNECT';
  return $self->disconnect($cb) if $cmd eq 'DISCONNECT';
  return $self->_join_dialog($message, $cb) if $cmd eq 'JOIN';
  return $self->_kick($target, $message, $cb) if $cmd eq 'KICK';
  return $self->_mode($target, $message, $cb) if $cmd eq 'MODE';
  return $self->participants($target, $cb) if $cmd eq 'NAMES';
  return $self->nick($message, $cb) if $cmd eq 'NICK';
  return $self->_part_dialog($message || $target, $cb) if $cmd eq 'CLOSE' or $cmd eq 'PART';
  return $self->_topic($target, $message, $cb) if $cmd eq 'TOPIC';
  return $self->_proxy(whois => $message, $cb) if $cmd eq 'WHOIS';
  return next_tick $self, $cb => 'Unknown IRC command.', undef;
}

sub _event_irc_close {
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
sub _event_irc_error {
  my ($self, $msg) = @_;
  $self->_notice(join ' ', @{$msg->{params}});
}

sub _irc_any {
  my ($self, $msg) = @_;

  return if grep { $msg->{command} eq $_ } qw(PONG);
  shift @{$msg->{params}} if $msg->{params}[0] eq $self->nick;

  $self->emit(
    message => $self->messages,
    {
      from => $msg->{prefix} // $self->id,
      highlight => Mojo::JSON->false,
      message   => join(' ', @{$msg->{params}}),
      ts        => time,
      type      => 'private',
    }
  );
}

sub _irc_message {
  my ($self, $event, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my ($from, $highlight, $target);

  # http://www.mirc.com/colors.html
  $msg->{params}[1] =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $msg->{params}[1] =~ s/[\x00-\x1f]//g;

  if ($user) {
    my $is_private = $self->_is_current_nick($msg->{params}[0]);
    $highlight = $is_private;
    $target    = $is_private ? $nick : $msg->{params}[0];
    $target    = $self->get_dialog($target) || $self->dialog({name => $target});
    $from      = $nick;
  }

  $target ||= $self->messages;
  $from ||= $msg->{prefix} // $self->id;

  $highlight ||= grep { $msg->{params}[1] =~ /\b\Q$_\E\b/i } $self->_irc->nick,
    @{$self->url->query->every_param('highlight')};

  $target->last_active(Mojo::Date->new->to_datetime);

  # server message or message without a dialog
  $self->emit(
    message => $target,
    {
      from      => $from,
      highlight => $highlight ? Mojo::JSON->true : Mojo::JSON->false,
      message   => $msg->{params}[1],
      ts        => time,
      type      => $event =~ /privmsg/ ? 'private' : $event =~ /action/ ? 'action' : 'notice',
    }
  );
}

sub _is_current_nick { lc $_[0]->_irc->nick eq lc $_[1] }

sub _join_dialog {
  my $cb = pop;
  my ($self, $command) = @_;
  my ($name, $password) = split /\s/, ($command || ''), 2;
  return next_tick $self, $cb, 'Command missing arguments.', undef unless $name and $name =~ /\S/;

  my $dialog = $self->get_dialog($name);
  return next_tick $self, $cb, '', $dialog if $dialog and !$dialog->frozen;
  Scalar::Util::weaken($self);
  return $self->_proxy(
    join_channel => $command,
    sub {
      my ($irc, $err, $res) = @_;
      $dialog ||= $self->dialog({name => $res->{name}});
      $dialog->frozen($err || '')->password($password // '')->topic($res->{topic} // '');
      $self->save(sub { })->$cb($err, $dialog);
    }
  );
}

sub _kick {
  my ($self, $target, $command, $cb) = @_;
  my ($nick, $reason) = split /\s/, $command, 2;

  return $self->_proxy(kick => "$target $nick :$reason", sub { $self->$cb(@_[1, 2]) });
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
  return $self->tap(remove_dialog => $name)->save($cb) if $dialog and $dialog->is_private;
  return $self->tap(remove_dialog => $name)->save($cb) if $self->state eq 'disconnected';
  return $self->_proxy(
    part_channel => $name,
    sub {
      my ($irc, $err) = @_;
      $self->tap(remove_dialog => $name)->save($cb);
    }
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
    return next_tick $self, $cb => 'Cannot send without target.';
  }
  elsif ($target =~ /\s/) {
    return next_tick $self, $cb => 'Cannot send message to target with spaces.';
  }
  elsif (length $message) {
    $msg = $self->_irc->parser->parse(sprintf ':%s PRIVMSG %s :%s', $self->_irc->nick, $target,
      $message);
    return next_tick $self, $cb => 'Unable to construct PRIVMSG.' unless ref $msg;
  }
  else {
    return next_tick $self, $cb => 'Cannot send empty message.';
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

_event err_cannotsendtochan => sub {
  my ($self, $msg) = @_;
  $self->_notice("Cannot send to channel $msg->{params}[1].");
};

_event err_erroneusnickname => sub {
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1] || 'unknown';
  $self->_notice("Invalid nickname $nick.");
};

_event err_nicknameinuse => sub {    # TODO
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->_notice("Nickname $nick is already in use.") unless $self->{err_nicknameinuse}{$nick}++;
};

_event irc_join => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $channel = $msg->{params}[0];

  if ($self->_is_current_nick($nick)) {
    my $dialog = $self->dialog({name => $channel, frozen => ''});
    $self->emit(state => frozen => $dialog->TO_JSON);
  }
  elsif (my $dialog = $self->get_dialog($channel)) {
    $self->emit(state => join => {dialog_id => $dialog->id, nick => $nick}) if $dialog;
  }
};

_event irc_kick => sub {
  my ($self, $msg) = @_;
  my ($kicker) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->dialog({name => $msg->{params}[0]});
  my $nick   = $msg->{params}[1];
  my $reason = $msg->{params}[2] || '';

  $self->emit(state => part =>
      {dialog_id => $dialog->id, kicker => $kicker, nick => $nick, message => $reason});
};

# :superman!superman@i.love.debian.org MODE superman :+i
# :superman!superman@i.love.debian.org MODE #convos superman :+o
# :hybrid8.debian.local MODE #no_such_room +nt
_event irc_mode => sub {
  my ($self, $msg) = @_;
  my ($from) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->get_dialog({name => $msg->{params}[0]}) or return;
  my $mode = $msg->{params}[1] || '';
  my $nick = $msg->{params}[2] || '';

  $self->emit(
    state => mode => {dialog_id => $dialog->id, from => $from, mode => $mode, nick => $nick});
};

# :Superman12923!superman@i.love.debian.org NICK :Supermanx
_event irc_nick => sub {
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
};

_event irc_part => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $dialog = $self->get_dialog($msg->{params}[0]);
  my $reason = $msg->{params}[1] || '';

  if ($dialog and !$self->_is_current_nick($nick)) {
    $self->emit(state => part => {dialog_id => $dialog->id, nick => $nick, message => $reason});
  }
};

_event irc_quit => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});

  $self->emit(state => quit => {nick => $nick, message => join ' ', @{$msg->{params}}});
};

# :hybrid8.debian.local 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh
_event irc_rpl_myinfo => sub {
  my ($self, $msg) = @_;
  my @keys = qw(nick real_host version available_user_modes available_channel_modes);
  my $i    = 0;

  $self->{myinfo}{$_} = $msg->{params}[$i++] // '' for @keys;
  $self->emit(state => me => $self->{myinfo});
};

# :hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
_event irc_rpl_welcome => sub {
  my ($self, $msg) = @_;
  my @commands = @{$self->on_connect_commands};
  my $write;

  $self->_notice($msg->{params}[1]);    # Welcome to the debian Internet Relay Chat Network superman
  $self->{myinfo}{nick} = $msg->{params}[0];
  $self->emit(state => me => $self->{myinfo});
  $self->_join_dialog(join(' ', $_->name, $_->password), sub { }) for @{$self->dialogs};

  # TODO: This is very experimental
  Scalar::Util::weaken($self);
  $write = sub {
    my $cmd = shift @commands or return;
    $self and $self->send('', $cmd, $write);
  };
  $write->();
};

# :superman!superman@i.love.debian.org TOPIC #convos :cool
_event irc_topic => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $dialog = $self->dialog({name => $msg->{params}[0], topic => $msg->{params}[1]});

  $self->emit(state => topic => $dialog->TO_JSON)->save(sub { });

  return $self->_notice("Topic unset by $nick") unless $dialog->topic;
  return $self->_notice("$nick changed the topic to: " . $dialog->topic);
};

sub DESTROY {
  my $self = shift;
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

=head2 rooms

See L<Convos::Core::Connection/rooms>.

=head2 send

See L<Convos::Core::Connection/send>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
