package Convos::Core::Connection::Irc;

=head1 NAME

Convos::Core::Connection::Irc - IRC connection for Convos

=head1 DESCRIPTION

L<Convos::Core::Connection::Irc> is a connection class for L<Convos> which
allow you to communicate over the IRC protocol.

=cut

no warnings 'utf8';
use Mojo::Base 'Convos::Core::Connection';
use Mojo::IRC::UA;
use Parse::IRC ();
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;
use constant STEAL_NICK_INTERVAL => $ENV{CONVOS_STEAL_NICK_INTERVAL} || 60;

require Convos;

# allow jumping between event names in your editor by matching whole words
# "_event irc_topic => sub {}" vs "sub _event_irc_topic"
sub _event { Mojo::Util::monkey_patch(__PACKAGE__, "_event_$_[0]" => $_[1]); }

my $CHANNEL_RE = qr{[#&]};

=head1 ATTRIBUTES

L<Convos::Core::Connection::Irc> inherits all attributes from L<Convos::Core::Connection>
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

L<Convos::Core::Connection::Irc> inherits all methods from L<Convos::Core::Connection>
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

  warn "[@{[$self->user->email]}/@{[$self->id]}] connect($irc->{server})\n" if DEBUG;

  return $self->tap($cb, "Invalid URL: hostname is not defined.") unless $irc->server;
  delete $self->{disconnect};
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

      return $self->state(disconnected => $err)->$cb($err) if $err;
      $self->{myinfo} ||= {};
      $self->state(connected => "Connected to $irc->{server}.")->$cb('');
    }
  );

  return $self;
}

=head2 disconnect

See L<Convos::Core::Connection/disconnect>.

=cut

sub disconnect {
  my ($self, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->{disconnect} = 1;
  $self->_irc->disconnect(sub { $self->state('disconnected')->$cb($_[1] || '') });
  $self;
}

=head2 join_conversation

See L<Convos::Core::Connection/join_conversation>.

=cut

sub join_conversation {
  my $cb   = pop;
  my $self = shift;
  my ($name, $password) = split /\s/, shift, 2;
  my $conversation;

  $conversation = $self->conversation($name, {active => 1, name => $name, password => $password // ''});
  return $self->tap($cb, '', $conversation) if $conversation->isa('Convos::Core::Conversation::Direct');
  return $self->tap($cb, '', $conversation) if %{$conversation->users};
  Scalar::Util::weaken($self);
  $self->_irc->join_channel(
    $name,
    sub {
      my ($irc, $err) = @_;
      delete $self->{conversations}{$conversation->id} if $err;
      $self->$cb($err, $conversation);
    }
  );
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

=head2 conversation

Force C<$id> to be lowercase. See L<Convos::Core::Connection/conversation>.

=cut

sub conversation {
  my ($self, $id, @args) = @_;
  $self->SUPER::conversation(lc $id, @args);
}

=head2 rooms

See L<Convos::Core::Connection/rooms>.

=cut

sub rooms {
  my ($self, $cb) = @_;

  # TODO: Add fresh() to get new list of channels on the server
  if ($self->{rooms_cache}) {
    Mojo::IOLoop->next_tick(sub { $self->$cb('', $self->{rooms_cache}); });
    return $self;
  }

  Scalar::Util::weaken($self);
  $self->_irc->channels(
    sub {
      my ($irc, $err, $channels) = @_;
      my $last = $self->{last_irc_rpl_listend} || 0;
      my $n = 0;

      return $self->$cb($err, $channels) if $err;

      for my $name (keys %$channels) {
        my $id           = lc $name;
        my $conversation = $self->conversation($id);
        $channels->{$name}{topic} =~ s!^\[\S+\]\s?!!;    # remove channel modes, such as "[+nt]"
        $conversation->name($name)->topic($channels->{$name}{topic})->{n_users} = $channels->{$name}{n_users};
        push @{$self->{rooms_cache}}, $conversation;
      }

      $self->{last_irc_rpl_listend} = time;
      $self->$cb('', $self->{rooms_cache});
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

  if (not length($target // '') or not length($message // '')) {    # err_norecipient and err_notexttosend
    Mojo::IOLoop->next_tick(sub { $self->$cb('Cannot send without target and message.'); });
    return $self;
  }
  if ($target =~ /\s/) {
    Mojo::IOLoop->next_tick(sub { $self->$cb('Cannot send message to target with spaces.'); });
    return $self;
  }

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

sub _conversation {
  my ($self, $args) = @_;
  $args->{class} = sprintf 'Convos::Core::Conversation::%s', $args->{id} =~ /^$CHANNEL_RE/ ? 'Room' : 'Direct'
    if $args->{id};
  $self->SUPER::_conversation($args);
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
  $self->_notice(join(' ', @{$msg->{params}}), highlight => Mojo::JSON->true);
}

sub _irc_message {
  my ($self, $event, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $target = $msg->{params}[0];

  if ($user) {
    my $current_nick = $self->_irc->nick;
    my $is_private   = $self->_is_current_nick($target);
    my $highlight    = $is_private || grep { $msg->{params}[1] =~ /\b\Q$_\E\b/ } $current_nick,
      @{$self->url->query->every_param('highlight')};

    $self->emit(
      message => $self->conversation($is_private ? $nick : $target, {}),
      {
        from      => $nick,
        highlight => $highlight ? Mojo::JSON->true : Mojo::JSON->false,
        message   => $msg->{params}[1],
        type      => $event eq 'irc_privmsg' ? 'private' : $event eq 'ctcp_action' ? 'action' : 'notice',
      }
    );
  }
  else {    # server message
    $self->emit(
      message => $self,
      {
        from => $msg->{prefix} // $self->_irc->server,
        highlight => Mojo::JSON->false,
        message   => $msg->{params}[1],
        type      => $event eq 'irc_privmsg' ? 'private' : 'notice',
      }
    );
  }
}

sub _is_current_nick { lc $_[0]->_irc->nick eq lc $_[1] }

sub _notice {
  my ($self, $message) = (shift, shift);
  $self->emit(
    message => $self,
    {from => $self->url->host, highlight => Mojo::JSON->false, type => 'notice', @_, message => $message}
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
  my $nick         = $self->_irc->nick;
  my $conversation = $self->conversation($channel);

  $conversation->frozen($reason =~ s/channel/channel $channel/i ? $reason : "$reason $channel") if $conversation;
  $self->_notice("$nick is banned from $channel [$reason]", highlight => Mojo::JSON->true);
};

_event err_cannotsendtochan => sub {
  my ($self, $msg) = @_;
  $self->_notice("Cannot send to channel $msg->{params}[1].", highlight => Mojo::JSON->true);
};

_event err_nicknameinuse => sub {    # TODO
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->_notice(qq(Nickname $nick is already in use.), highlight => Mojo::JSON->true)
    unless $self->{err_nicknameinuse}{$nick}++;
};

# :hybrid8.debian.local 401 Superman #no_such_channel_ :No such nick/channel
_event err_nosuchnick => sub {
  my ($self, $msg) = @_;

  if (my $conversation = $self->conversation($msg->{params}[1])) {
    $self->emit(
      message => $conversation,
      {
        from      => $self->url->host,
        highlight => Mojo::JSON->true,
        message   => 'No such nick or channel.',
        type      => 'notice',
      }
    );
  }

  $self->_notice("No such nick or channel $msg->{params}[1].");
};

# :superman!superman@i.love.debian.org JOIN :#convos
_event irc_join => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $conversation = $self->conversation($msg->{params}[0], {frozen => '', name => $msg->{params}[0]});

  $conversation->users->{lc($nick)} ||= {host => $host, name => $nick, user => $user};
  $self->emit(users => $conversation, {join => lc($nick)});
};

# TODO
_event irc_kick => sub {
  my ($self, $msg) = @_;
  my ($kicker)     = IRC::Utils::parse_user($msg->{prefix});
  my $conversation = $self->conversation($msg->{params}[0]);
  my $nick         = $msg->{params}[1];
  my $reason = $msg->{params}[2] || '';

  delete $conversation->users->{lc($nick)};
  $self->emit(users => $conversation, {kicker => $kicker, part => lc($nick), message => $reason});
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

  delete $self->{err_nicknameinuse} if $wanted_nick and $wanted_nick eq $new_nick;   # allow warning on next nick change

  if ($self->_is_current_nick($new_nick)) {
    $self->{myinfo}{nick} = $new_nick;
    $self->emit(me => $self->{myinfo});
  }

  for my $conversation (values %{$self->{conversations}}) {
    my $info = delete $conversation->users->{$old_nick_lc} or next;
    $info->{name} = $new_nick;
    $conversation->{users}{lc($new_nick)} = $info;
    $self->emit(users => $conversation => {%$info, renamed_from => $old_nick_lc});
  }
};

_event irc_part => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $conversation = $self->conversation($msg->{params}[0]);
  my $reason = $msg->{params}[1] || '';

  # logging is the same as irssi

  if ($self->_is_current_nick($nick)) {
    delete $self->{conversations}{$conversation->id};
    $conversation->frozen('Parted.');
  }

  delete $conversation->users->{lc($nick)};
  $self->emit(users => $conversation => {part => lc($nick), message => $reason});
};

_event irc_quit => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $nick_lc = lc $nick;
  my $reason = $msg->{params}[1] || '';

  for my $conversation (values %{$self->{conversations}}) {
    delete $conversation->users->{$nick_lc} or next;
    $self->emit(users => $conversation => {part => $nick_lc, message => $reason});
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
  my $channel      = $msg->{params}[1];
  my $conversation = $self->conversation($channel, {name => $channel});
  my $users        = $conversation->users;
  my $last         = $conversation->{last_irc_rpl_endofnames} || 0;

  for my $nick (keys %$users) {
    my $info = $users->{$nick};
    next if $last <= $info->{seen};
    delete $users->{$nick};
  }

  $conversation->{last_irc_rpl_endofnames} = time;
  $self->emit(users => $conversation => {updated => Mojo::JSON->true});
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
  my $users = $self->conversation($msg->{params}[2])->users;

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
  my $conversation = $self->conversation($msg->{params}[1] => {topic => $msg->{params}[2]});
  $self->_notice(sprintf 'Topic for %s: %s', $conversation->name, $conversation->topic);
};

# :hybrid8.debian.local 333 superman #convos jhthorsen!jhthorsen@i.love.debian.org 1432142279
_event irc_rpl_topicwhotime => sub {
  my ($self, $msg) = @_;    # TODO
  my $conversation = $self->conversation($msg->{params}[1] => {topic_by => $msg->{params}[2]});

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
  $self->join_conversation(join(' ', $_->name, $_->password), sub { }) for grep { $_->active } @{$self->conversations};
};

# :superman!superman@i.love.debian.org TOPIC #convos :cool
_event irc_topic => sub {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix} || '');
  my $conversation = $self->conversation($msg->{params}[0] => {topic => $msg->{params}[1]});

  return $self->_notice("Topic unset by $nick") unless $conversation->topic;
  return $self->_notice("$nick changed the topic to: " . $conversation->topic);
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
