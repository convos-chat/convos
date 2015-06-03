package Convos::Core::Connection::IRC;

=head1 NAME

Convos::Core::Connection::IRC - IRC connection for Convos

=head1 DESCRIPTION

L<Convos::Core::Connection::IRC> is a connection class for L<Convos> which
allow you to communicate over the IRC protocol.

=cut

no warnings 'utf8';
use Mojo::Base 'Convos::Core::Connection';
use Mojo::IRC::UA;
use Parse::IRC ();
use constant STEAL_NICK_INTERVAL => $ENV{CONVOS_STEAL_NICK_INTERVAL} || 60;

require Convos;

# allow jumping between event names in your editor by matching whole words
# "_event irc_topic => sub {}" vs "sub _event_irc_topic"
sub _event { Mojo::Util::monkey_patch(__PACKAGE__, "_event_$_[0]" => $_[1]); }

=head1 ATTRIBUTES

L<Convos::Core::Connection::IRC> inherits all attributes from L<Convos::Core::Connection>
and implements the following new ones.

=cut

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

  for my $event ('ctcp_action', 'irc_notice', 'irc_privmsg') {
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

=head1 METHODS

L<Convos::Core::Connection::IRC> inherits all methods from L<Convos::Core::Connection>
and implements the following new ones.

=head2 connect

See L<Convos::Core::Connection/connect>.

=cut

sub connect {
  my ($self, $cb) = @_;
  my $irc      = $self->_irc;
  my $userinfo = $self->_userinfo;
  my $url      = $self->url;

  $irc->user($userinfo->[0]);
  $irc->pass($userinfo->[1]);
  $irc->server($url->host_port) unless $irc->server;
  $irc->tls(($url->query->param('tls') // 1) ? {} : undef);

  return $self->tap($cb, "Invalid URL: hostname is not defined.") unless $irc->server;

  Scalar::Util::weaken($self);
  $self->state('connecting');
  $self->{steal_nick_tid} ||= $irc->ioloop->recurring(STEAL_NICK_INTERVAL, sub { $self->_steal_nick });
  $irc->connect(
    sub {
      my ($irc, $err) = @_;

      if ($err =~ /IO::Socket::SSL/ or $err =~ /SSL.*HELLO/) {
        $url->query->param(tls => 0);
        $self->save(sub { })    # save updated URL
      }

      return $self->log(warn => $err)->$cb($err) if $err;
      $self->{myinfo} ||= {};
      $self->state('connected')->log(info => "Connected to $irc->{server}.")->$cb('');
    }
  );

  return $self;
}

=head2 join_room

See L<Convos::Core::Connection/join_room>.

=cut

sub join_room {
  my ($self, $channel, $cb) = @_;
  return $self->tap($cb, "", $self->room($channel)) if %{$self->room($channel)->users};
  Scalar::Util::weaken($self);
  $self->_irc->join_channel($channel, sub { $self->$cb($_[1], $self->room($channel)); });
  $self;
}

=head2 nick

  $self = $self->nick($nick => sub { my ($self, $err) = @_; });
  $self = $self->nick(sub { my ($self, $err, $nick) = @_; });
  $nick = $self->nick;

Used to set or get the nick for this connection. Setting this nick will change
L</nick> and try to change the nick on server if connected. Getting this nick
will retrieve the active nick on server if connected and fall back to returning
L</nick>.

=cut

sub nick {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, @nick) = @_;    # @nick will be empty list on "get"

  return $self->_irc->nick(@nick) unless $cb;
  Scalar::Util::weaken($self);
  $self->url->query->param(nick => $nick[0]) if @nick;
  $self->_irc->nick(@nick, sub { shift; $self->$cb(@_) });
  $self;
}

=head2 room

Force C<$id> to be lowercase. See L<Convos::Core::Connection/room>.

=cut

sub room {
  my ($self, $id, @args) = @_;
  $self->SUPER::room(lc $id, @args);
}

=head2 room_list

See L<Convos::Core::Connection/room_list>.

=cut

sub room_list {
  my ($self, $cb) = @_;

  if (time < ($self->{last_irc_rpl_listend} || 0) - 60) {
    return $self->$cb('', [values %{$self->{room}}]);
  }

  Scalar::Util::weaken($self);
  $self->_irc->channels(
    sub {
      my ($irc, $err, $channels) = @_;
      my $last = $self->{last_irc_rpl_listend} || 0;
      my $n = 0;

      return $self->$cb($err, $channels) if $err;

      for my $name (keys %$channels) {
        my $id = lc $name;
        my $room = $self->room($id, {name => $name});
        $room->topic($channels->{$name}{topic}) unless $room->topic;
        $room->{n_users} = $channels->{$name}{n_users};
      }

      $self->{last_irc_rpl_listend} = time;
      $self->$cb('', [values %{$self->{room}}]);
    },
  );

  return $self;
}

=head2 send

See L<Convos::Core::Connection/send>.

=cut

sub send {
  my ($self, $target, $message, $cb) = @_;
  my $msg;

  return $self->tap($cb, "Cannot send without target and message.")
    unless length($target // '') and length($message // '');    # err_norecipient and err_notexttosend
  return $self->tap($cb, "Cannot send message to target with spaces.") if $target =~ /\s/;

  $msg = Parse::IRC::parse_irc(sprintf ':%s PRIVMSG %s :%s', $self->_irc->nick, $target, $message);

  # Seems like there is no way to know if a message is delivered
  # Instead, there might be some errors occuring if the message had issues:
  # err_cannotsendtochan, err_nosuchnick, err_notoplevel, err_toomanytargets,
  # err_wildtoplevel, irc_rpl_away

  Scalar::Util::weaken($self);
  return $self->tap($cb, qq(Cannot send invalid message "$message" to $target.)) unless ref $msg;
  $self->_irc->write(
    $msg->{raw_line},
    sub {
      my ($irc, $err) = @_;
      return $self->$cb($err) if $err;
      $msg->{prefix} = sprintf '%s!%s@%s', $irc->nick, $irc->user, $irc->server;
      $self->_irc_message(irc_privmsg => $msg);
      $self->$cb('');
    }
  );
  return $self;
}

=head2 topic

See L<Convos::Core::Connection/topic>.

=cut

sub topic {
  my $cb   = pop;
  my $self = shift;
  Scalar::Util::weaken($self);
  $self->_irc->channel_topic(@_, sub { shift; $self->$cb(@_); });
  $self;
}

=head2 whois

See L<Convos::Core::Connection/whois>.

=cut

sub whois {
  my ($self, $target, $cb) = @_;
  return $self->tap($cb, "Cannot retrieve whois without target.", {}) unless $target;    # err_nonicknamegiven
  Scalar::Util::weaken($self);
  $self->_irc->whois($target, sub { shift; $self->$cb(@_); });
  $self;
}

sub _event_irc_close {
  my ($self) = @_;
  $self->state(delete $self->{disconnect} ? 'disconnected' : 'connecting');
  $self->log(
    info => 'You [%s@%s] have quit [Connection closed.]',
    $self->_irc->nick, $self->_irc->real_host || $self->url->host
  );
  delete $self->{_irc};
}

# Unhandled/unexpected error
sub _event_irc_error {
  my ($self, $msg) = @_;
  $self->log(error => join ' ', @{$msg->{params}});
}

sub _irc_message {    # TODO
  my ($self, $event, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $format             = $event eq 'irc_privmsg' ? '<%s> %s' : $event eq 'ctcp_action' ? '* %s %s' : '-%s- %s';
  my $target             = $msg->{params}[0];
  my $current_nick       = $self->_irc->nick;
  my $is_private_message = $self->_is_current_nick($target);

  if ($user) {
    my $room = $self->room($is_private_message ? $nick : $target, {});
    my $highlight = $is_private_message || grep { $msg->{params}[1] =~ /\b\Q$_\E\b/ } $current_nick,
      @{$self->url->query->every_param('highlight')};
    $room->log(($highlight ? 'warn' : 'info'), $format, $nick, $msg->{params}[1]);
  }
  else {
    $self->log(info => $format, $msg->{prefix} // $self->_irc->server, $msg->{params}[1]);
  }
}

sub _is_current_nick { lc $_[0]->_irc->nick eq lc $_[1] }

sub _steal_nick {
  my $self = shift;
  my $nick = $self->url->query->param('nick');
  $self->_irc->write("NICK $nick") if $nick and $self->_irc->nick ne $nick;
}

# :hybrid8.debian.local 474 superman #convos :Cannot join channel (+b)
_event err_bannedfromchan => sub {    # TODO
  my ($self,    $msg)    = @_;
  my ($channel, $reason) = @{$msg->{params}};
  my $room = $self->room($channel => {});

  $room->frozen($reason =~ s/channel/channel $channel/i ? $reason : "$reason $channel");
  $room->log(warn => '-!- %s is banned from %s [%s]', $self->_irc->nick, $channel, $room->frozen);
};

_event err_cannotsendtochan => sub {
  my ($self, $msg) = @_;
  $self->log(debug => 'Cannot send to channel %s.', $msg->{params}[1]);
};

_event err_nicknameinuse => sub {    # TODO
  my ($self, $msg) = @_;
  my $nick_in_use = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->log(warn => 'Nickname %s is already in use.', $nick_in_use) unless $self->{err_nicknameinuse}{$nick_in_use}++;
};

# :hybrid8.debian.local 401 Superman #no_such_channel_ :No such nick/channel
_event err_nosuchnick => sub {
  my ($self, $msg) = @_;
  $self->log(debug => 'No such nick or channel %s.', $msg->{params}[1]);
};

# :superman!superman@i.love.debian.org JOIN :#convos
_event irc_join => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $room = $self->room($msg->{params}[0], {frozen => '', name => $msg->{params}[0]});

  $room->users->{lc($nick)} ||= {name => $nick};
  $room->log(debug => '-!- %s [%s@%s] has joined %s', $nick, $user, $host, $room->name);    # same as irssi
};

# TODO
_event irc_kick => sub {
  my ($self, $msg) = @_;
  my ($by) = IRC::Utils::parse_user($msg->{prefix});
  my $room = $self->room($msg->{params}[0]);
  my $nick = $msg->{params}[1];
  my $reason = $msg->{params}[2] || '';

  if ($self->_is_current_nick($nick)) {
    $room->log(warn => '-!- %s was kicked from %s by %s [%s]', $nick, $room->name, $by, $reason);    # same as irssi
    $room->frozen("Kicked by $by.");
  }
  else {
    $room->log(debug => '-!- %s was kicked from %s by %s [%s]', $nick, $room->name, $by, $reason);    # same as irssi
  }

  delete $room->users->{lc($nick)};
  $self->emit(users => $room->id => $room->users);
};

# :superman!superman@i.love.debian.org MODE superman :+i
# :superman!superman@i.love.debian.org MODE #convos superman :+o
# :hybrid8.debian.local MODE #no_such_room +nt
_event irc_mode => sub {
  my ($self, $msg) = @_;                                                                              # TODO
};

# :Superman12923!superman@i.love.debian.org NICK :Supermanx12923
_event irc_nick => sub {
  my ($self, $msg) = @_;
  my ($old_nick)  = IRC::Utils::parse_user($msg->{prefix});
  my $old_nick_lc = lc $old_nick;
  my $new_nick    = $msg->{params}[0];
  my $wanted_nick = $self->url->query->param('nick');

  delete $self->{err_nicknameinuse} if $wanted_nick and $wanted_nick eq $new_nick;   # allow warning on next nick change
  $self->emit(nick => $new_nick) if $self->_is_current_nick($new_nick);

  for my $room (values %{$self->{room}}) {
    my $info = delete $room->users->{$old_nick_lc} or next;
    $info->{name} = $new_nick;
    $room->{users}{lc($new_nick)} = $info;
    $room->log(debug => '-!- %s is now known as %s', $old_nick, $new_nick);          # same as irssi
    $self->emit(users => $room->id => $room->users);
  }
};

_event irc_part => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $room = $self->room($msg->{params}[0]);
  my $reason = $msg->{params}[1] || '';

  if ($self->_is_current_nick($nick)) {
    delete $self->{room}{$room->id};
    $room->log(info => '-!- %s [%s@%s] has left %s [%s]', $nick, $user, $host, $room->name, $reason);    # same as irssi
    $room->frozen('Parted.');
  }
  else {
    $room->log(debug => '-!- %s [%s@%s] has left %s [%s]', $nick, $user, $host, $room->name, $reason);   # same as irssi
  }

  delete $room->users->{lc($nick)};
  $self->emit(users => $room->id => $room->users);
};

_event irc_quit => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $nick_lc = lc $nick;
  my $reason = $msg->{params}[1] || '';

  for my $room (values %{$self->{room}}) {
    delete $room->users->{$nick_lc} or next;
    $room->log(debug => '-!- %s [%s@%s] has quit [%s]', $nick, $user, $host, $reason);    # same as irssi
    $self->emit(users => $room->id => $room->users);
  }
};

_event irc_rpl_away => sub {
  my ($self, $msg) = @_;
};

# :hybrid8.debian.local 376 superman :End of /MOTD command.
_event irc_rpl_endofmotd => sub {
  my ($self, $msg) = @_;
  $self->log(info => $msg->{params}[1]);
};

# :hybrid8.debian.local 366 superman #convos :End of /NAMES list.
# See also _irc_rpl_namreply()
_event irc_rpl_endofnames => sub {
  my ($self, $msg) = @_;
  my $channel = $msg->{params}[1];
  my $room    = $self->room($channel, {name => $channel});
  my $users   = $room->users;
  my $last    = $room->{last_irc_rpl_endofnames} || 0;

  for my $nick (keys %$users) {
    my $info = $users->{$nick};
    next if $last <= $info->{seen};
    delete $users->{$nick};
  }

  $room->{last_irc_rpl_endofnames} = time;
  $self->emit(users => $room->id => $room->users);
};

# :hybrid8.debian.local 372 superman :too cool for school
_event irc_rpl_motd => sub {
  $_[0]->log(info => $_[1]->{params}[1]);
};

# :hybrid8.debian.local 375 superman :- hybrid8.debian.local Message of the Day -
_event irc_rpl_motdstart => sub {
  $_[0]->log(info => $_[1]->{params}[1]);
};

# :hybrid8.debian.local 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh
_event irc_rpl_myinfo => sub {
  my ($self, $msg) = @_;
  my @keys = qw( current_nick real_host version available_user_modes available_channel_modes );
  my $i    = 0;

  $self->{myinfo}{$_} = $msg->{params}[$i++] // '' for @keys;
};

# :hybrid8.debian.local 353 superman = #convos :superman @jhthorsen
# See also _irc_rpl_endofnames()
_event irc_rpl_namreply => sub {
  my ($self, $msg) = @_;
  my $users = $self->room($msg->{params}[2])->users;

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
  my $room = $self->room($msg->{params}[1] => {topic => $msg->{params}[2]});
  $room->log(debug => '-!- Topic for %s: %s', $room->name, $room->topic);
};

# :hybrid8.debian.local 333 superman #convos jhthorsen!jhthorsen@i.love.debian.org 1432142279
_event irc_rpl_topicwhotime => sub {
  my ($self, $msg) = @_;    # TODO
  my $room = $self->room($msg->{params}[1] => {topic_by => $msg->{params}[2]});

  # irssi log message contains localtime(), but we already log to file with a timestamp
  $room->log(debug => '-!- Topic set by %s', $msg->{params}[2]);
};

# :hybrid8.debian.local 002 superman :Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2
_event irc_rpl_yourhost => sub {
  $_[0]->log(info => $_[1]->{params}[1]);
};

# :hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
_event irc_rpl_welcome => sub {
  my ($self, $msg) = @_;
  my $rooms = $self->rooms;
  $self->log(info => $msg->{params}[1]);    # Welcome to the debian Internet Relay Chat Network superman
  $self->emit(nick => $msg->{params}[0]);
  $self->join_room($_, sub { }) for @$rooms;
};

# :superman!superman@i.love.debian.org TOPIC #convos :cool
_event irc_topic => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $room = $self->room($msg->{params}[0] => {topic => $msg->{params}[1]});

  return $room->log(debug => '-!- Topic unset by %s', $nick) unless $room->topic;
  return $room->log(debug => '-!- %s changed the topic to: %s', $nick, $room->topic);
};

sub DESTROY {
  my $self = shift;
  my $ioloop = $self->{_irc}{ioloop} or return;
  my $tid;
  $ioloop->remove($tid) if $tid = $self->{steal_nick_tid};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
