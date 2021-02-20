package Convos::Core::Connection::Irc;
use Mojo::Base 'Convos::Core::Connection';

no warnings 'utf8';
use Convos::Util qw($CHANNEL_RE DEBUG);
use IRC::Utils ();
use Mojo::JSON qw(false true);
use Mojo::Parameters;
use Mojo::Util qw(b64_decode b64_encode gzip gunzip term_escape trim);
use Parse::IRC ();
use Socket;
use Time::HiRes 'time';

use constant IS_TESTING            => $ENV{HARNESS_ACTIVE}               || 0;
use constant MAX_BULK_MESSAGE_SIZE => $ENV{CONVOS_MAX_BULK_MESSAGE_SIZE} || 3;
use constant MAX_MESSAGE_LENGTH    => $ENV{CONVOS_MAX_MESSAGE_LENGTH}    || 512;
use constant PERIDOC_INTERVAL      => $ENV{CONVOS_IRC_PERIDOC_INTERVAL}  || 60;

require Convos;
our $VERSION = Convos->VERSION;

our $CONVOS_URL = 'https://convos.chat';
our %CTCP_QUOTE = ("\012" => 'n', "\015" => 'r', "\0" => '0', "\cP" => "\cP");

my %CLASS_DATA;
sub _available_conversations { $CLASS_DATA{conversations}{$_[0]->url->host} ||= {} }

sub disconnect_p {
  my $self = shift;
  my $p    = Mojo::Promise->new;
  return $p->resolve({}) unless $self->{stream};

  $self->{myinfo}{authenticated} = false;
  $self->{myinfo}{capabilities}  = {};
  $self->{disconnecting}         = 1;       # Prevent getting queued
  $self->_write("QUIT :$CONVOS_URL", sub { $self->_stream_remove($p) });
  return $p;
}

sub send_p {
  my ($self, $target, $message) = @_;

  $target  //= '';
  $message //= '';
  $message =~ s![\x00-\x09\x0b-\x1f]!!g;    # remove invalid characters
  $message =~ s!^\s*/!/!s;                  # Remove space in front of command
  $message =~ s![\r\n]+$!!s;

  unless ($message =~ s!^/([A-Za-z]+)\s*!!) {
    my $re = join '|', @{$self->service_accounts};
    $target = $1 if $message =~ s!^($re):\s+!!;
    return $self->_send_message_p($target, $message);
  }

  my $cmd = uc $1;

  return $self->_send_message_p($target, "\x{1}ACTION $message\x{1}") if $cmd eq 'ME';
  return $self->_send_message_p($target, $message)                    if $cmd eq 'SAY';
  return $self->_send_message_p(split /\s+/, $message, 2) if $cmd eq 'MSG';

  return $self->_send_clear_p(split /\s+/, $message) if $cmd eq 'CLEAR';
  return $self->_send_query_p($message)              if $cmd eq 'QUERY';
  return $self->_send_join_p($message)               if $cmd eq 'JOIN';
  return $self->_send_list_p($message)               if $cmd eq 'LIST';
  return $self->_send_nick_p($message)               if $cmd eq 'NICK';
  return $self->_send_whois_p($message)              if $cmd eq 'WHOIS';

  return $self->_send_names_p($target) if $cmd eq 'NAMES';

  return $self->_send_kick_p($target, $message)  if $cmd eq 'KICK';
  return $self->_send_mode_p($target, $message)  if $cmd eq 'MODE';
  return $self->_send_oper_p($target, $message)  if $cmd eq 'OPER';
  return $self->_send_topic_p($target, $message) if $cmd eq 'TOPIC';

  return $self->_send_ison_p($message || $target) if $cmd eq 'ISON';
  return $self->_send_part_p($message || $target) if $cmd eq 'CLOSE' or $cmd eq 'PART';

  return $self->_set_wanted_state_p('connected')    if $cmd eq 'CONNECT';
  return $self->_set_wanted_state_p('disconnected') if $cmd eq 'DISCONNECT';
  return $self->_write_p($message)                  if $cmd eq 'QUOTE';

  return Mojo::Promise->reject('Unknown command.');
}

sub _connect_args_p {
  my $self   = shift;
  my $url    = $self->url;
  my $params = $self->url->query;

  $self->_periodic_events;
  $url->port($params->param('tls') ? 6669 : 6667) unless $url->port;
  $params->param(nick => $self->nick)             unless $params->param('nick');
  $self->{myinfo}{authenticated} = false;
  $self->{myinfo}{capabilities}  = {};
  $self->{myinfo}{nick}          = $params->param('nick');

  return $self->SUPER::_connect_args_p;
}

sub _irc_event_900 { goto &_irc_event_sasl_status }    # RPL_LOGGEDIN
sub _irc_event_901 { goto &_irc_event_sasl_status }    # RPL_LOGGEDOUT
sub _irc_event_902 { goto &_irc_event_sasl_status }    # ERR_NICKLOCKED
sub _irc_event_903 { goto &_irc_event_sasl_status }    # RPL_SASLSUCCESS
sub _irc_event_904 { goto &_irc_event_sasl_status }    # ERR_SASLFAIL
sub _irc_event_905 { goto &_irc_event_sasl_status }    # ERR_SASLTOOLONG
sub _irc_event_906 { goto &_irc_event_sasl_status }    # ERR_SASLABORTED
sub _irc_event_907 { goto &_irc_event_sasl_status }    # ERR_SASLALREADY
sub _irc_event_908 { goto &_irc_event_cap }            # RPL_SASLMECHS

sub _irc_event_rpl_creationtime { }
sub _irc_event_rpl_endofmotd    { }

sub _irc_event_sasl_status {
  my ($self, $msg) = @_;
  $msg->{error} = 1 if $msg->{command} =~ m!90[14567]!;
  $self->_irc_event_fallback($msg);
  $self->{myinfo}{authenticated} = $msg->{command} =~ m!90[03]! ? true : false;
  $self->emit(state => me => $self->{myinfo});
  $self->_write("CAP END\r\n");
}

sub _irc_event_cap {
  my ($self, $msg) = @_;
  $self->_irc_event_fallback($msg);

  if ($msg->{raw_line} =~ m!\s(?:LIST|LS)[^:]+:(.*)!) {
    $self->{myinfo}{capabilities}{$_} = true for split /\s/, $1;
    my @cap_req;
    push @cap_req, 'sasl' if $self->{myinfo}{capabilities}{sasl} and $self->_sasl_mechanism;
    $self->_write(@cap_req ? sprintf "CAP REQ :%s\r\n", join ' ', @cap_req : "CAP END\r\n");
  }
  elsif ($msg->{raw_line} =~ m!\sACK\W*(.+)!) {
    my ($capabilities, $mech) = ($1, $self->_sasl_mechanism);
    $self->_write("AUTHENTICATE $mech\r\n") if $capabilities =~ m!\bsasl\b!;
  }
  else {
    $self->_write("CAP END\r\n");
  }
}

sub _irc_event_ctcp_action {
  shift->_irc_event_privmsg(@_);
}

sub _irc_event_ctcp_ping {
  my ($self, $msg) = @_;
  my $ts   = $msg->{params}[1] or return;
  my $nick = IRC::Utils::parse_user($msg->{prefix});
  $self->_write(sprintf "NOTICE %s %s\r\n", $nick, $self->_make_ctcp_string("PING $ts"));
}

sub _irc_event_ctcp_time {
  my ($self, $msg) = @_;
  my $nick = IRC::Utils::parse_user($msg->{prefix});
  $self->_write(sprintf "NOTICE %s %s\r\n",
    $nick, $self->_make_ctcp_string(TIME => scalar localtime));
}

sub _irc_event_ctcp_version {
  my ($self, $msg) = @_;
  my $nick = IRC::Utils::parse_user($msg->{prefix});
  $self->_write(sprintf "NOTICE %s %s\r\n",
    $nick, $self->_make_ctcp_string("VERSION Convos $VERSION"));
}

sub _irc_event_err_cannotsendtochan {
  my ($self, $msg) = @_;
  $self->_message("Cannot send to channel $msg->{params}[1].", type => 'error');
}

sub _irc_event_err_erroneusnickname {
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1] || 'unknown';
  $self->_message("Invalid nickname $nick.", type => 'error');
}

sub _irc_event_err_nicknameinuse {
  my ($self, $msg) = @_;
  my $nick = $msg->{params}[1];

  # do not want to flod frontend with these messages
  $self->_message("Nickname $nick is already in use.", type => 'error')
    unless $self->{err_nicknameinuse}{$nick}++;

  $self->{myinfo}{nick} = "${nick}_";
  $self->emit(state => me => $self->{myinfo});
  Mojo::IOLoop->timer(0.2 => sub { $self and $self->_write("NICK $self->{myinfo}{nick}\r\n") });
}

sub _irc_event_err_unknowncommand {
  my ($self, $msg) = @_;
  $self->_message("Unknown command: $msg->{params}[1]", type => 'error');
}

sub _irc_event_error {
  my ($self, $msg) = @_;
  $self->_irc_event_fallback($msg);
  $self->{failed_to_connect}++ if $msg->{params}[0] =~ m!Trying to reconnect too fast!i;
}

sub _irc_event_fallback {
  my ($self, $msg) = @_;

  my @params = @{$msg->{params}};
  shift @params if $self->_is_current_nick($params[0]);

  $self->emit(
    message => $self->messages,
    {
      from      => $self->id,
      highlight => false,
      message   => join(' ', @params),
      ts        => time,
      type      => $msg->{error} || $msg->{command} =~ m!err! ? 'error' : 'notice',
    }
  );
}

sub _irc_event_join {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $channel = $msg->{params}[0];

  if ($self->_is_current_nick($nick)) {
    my $conversation = $self->conversation({name => $channel, frozen => ''});
    $self->emit(state => frozen => $conversation->TO_JSON);
    $self->_write("TOPIC $channel\r\n");    # Topic is not part of the join response
  }
  elsif (my $conversation = $self->get_conversation($channel)) {
    $self->emit(state => join => {conversation_id => $conversation->id, nick => $nick});
  }
}

sub _irc_event_kick {
  my ($self, $msg) = @_;
  my ($kicker)     = IRC::Utils::parse_user($msg->{prefix});
  my $conversation = $self->conversation({name => $msg->{params}[0]});
  my $nick         = $msg->{params}[1];
  my $reason       = $msg->{params}[2] || '';

  $self->emit(state => part =>
      {conversation_id => $conversation->id, kicker => $kicker, nick => $nick, message => $reason});
}

# :superman!superman@i.love.debian.org MODE superman :+i
# :superman!superman@i.love.debian.org MODE #convos superman :+o
# :hybrid8.debian.local MODE #no_such_room +nt
sub _irc_event_mode {
  my ($self, $msg) = @_;
  return if $msg->{handled};

  my $mode = $msg->{params}[1] || '';
  if ($mode =~ /(o|v)$/ and $msg->{params}[2]) {
    my $nick = $msg->{params}[2];
    my ($from) = IRC::Utils::parse_user($msg->{prefix});
    $self->emit(state => mode =>
        {conversation_id => lc $msg->{params}[0], from => $from, mode => $mode, nick => $nick});
  }
  else {
    my $params = $msg->{params}[2] // '';
    $params =~ s!.!*!g if $mode =~ /k/;
    $self->_notice("$msg->{params}[0] changed mode $mode $params");
  }
}

sub _irc_event_rpl_motd {
  my ($self, $msg) = @_;

  my $message = $msg->{params}[1];
  $message =~ s!^-\s!!;

  $self->emit(
    message => $self->messages,
    {
      from      => $msg->{prefix} || $self->id,
      highlight => false,
      message   => $message,
      ts        => time,
      type      => 'preformat',
    }
  );
}

# :Superman12923!superman@i.love.debian.org NICK :Supermanx
sub _irc_event_nick {
  my ($self, $msg) = @_;
  my ($old_nick)  = IRC::Utils::parse_user($msg->{prefix});
  my $new_nick    = $msg->{params}[0];
  my $wanted_nick = $self->url->query->param('nick');

  if ($wanted_nick and $wanted_nick eq $new_nick) {
    delete $self->{err_nicknameinuse};    # allow warning on next nick change
  }

  if ($self->{myinfo}{nick} eq $old_nick) {
    $self->{myinfo}{nick} = $new_nick;
    $self->emit(state => me => $self->{myinfo});
  }
  else {
    $self->emit(state => nick_change => {new_nick => $new_nick, old_nick => $old_nick});
  }
}

sub _irc_event_part {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my $conversation = $self->get_conversation($msg->{params}[0]);
  my $reason       = $msg->{params}[1] || '';

  if ($conversation and !$self->_is_current_nick($nick)) {
    $self->emit(
      state => part => {conversation_id => $conversation->id, nick => $nick, message => $reason});
  }
}

sub _irc_event_ping {
  my ($self, $msg) = @_;
  $self->_write("PONG $msg->{params}[0]\r\n");
}

# Do not care about the PING response
sub _irc_event_pong { }

sub _irc_event_notice {
  my ($self, $msg) = @_;

  # AUTH :*** Ident broken or disabled, to continue to connect you must type /QUOTE PASS 21105
  $self->_write("QUOTE PASS $1\r\n") if $msg->{params}[0] =~ m!Ident broken.*QUOTE PASS (\S+)!;

  $self->_irc_event_privmsg($msg);
}

sub _irc_event_privmsg {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  my ($from, $highlight, $target);

  my ($conversation_id, @message) = @{$msg->{params}};
  $message[0] = join ' ', @message;

  # http://www.mirc.com/colors.html
  $message[0] =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $message[0] =~ s/[\x00-\x1f]//g;

  if (grep { $_ eq lc $nick || $_ eq lc $conversation_id } map {lc} @{$self->service_accounts}) {
    $target = $self->_is_current_nick($conversation_id) ? $nick : $conversation_id;
    $target = $self->get_conversation($target) || $self->messages;
    $from   = $nick;
  }
  elsif ($user) {
    $target = $self->_is_current_nick($conversation_id) ? $nick : $conversation_id;
    $target = $self->get_conversation($target) || $self->conversation({name => $target});
    $from   = $nick;
  }

  $target ||= $self->messages;
  $from   ||= $self->id;

  unless ($self->_is_current_nick($nick)) {
    $highlight = grep { $message[0] =~ /\b\Q$_\E\b/i } $self->nick,
      @{$self->user->highlight_keywords};

    # The unread count will be saved periodically by _periodic_events()
    $target->inc_unread_p->catch(sub { $self->_debug('inc_unread %s FAIL %s', $target->id, shift) }
    );
  }

  # server message or message without a conversation
  $self->emit(
    message => $target,
    {
      from      => $from,
      highlight => $highlight ? true : false,
      message   => $message[0],
      ts        => time,
      type      => _message_type($msg),
    }
  );
}

sub _irc_event_quit {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});

  $self->emit(state => quit => {nick => $nick, message => join ' ', @{$msg->{params}}});
}

sub _irc_event_rpl_list {
  my ($self, $msg) = @_;
  my $conversation = {n_users => 0 + $msg->{params}[2], topic => $msg->{params}[3]};

  $conversation->{name}            = $msg->{params}[1];
  $conversation->{conversation_id} = lc $conversation->{name};
  $conversation->{topic} =~ s!^(\[\+[a-z]+\])\s?!!;    # remove mode from topic, such as [+nt]
  $self->_available_conversations->{conversations}{$conversation->{name}} = $conversation;
}

sub _irc_event_rpl_listend {
  my ($self, $msg) = @_;
  $self->_available_conversations->{done} = true;
}

# :hybrid8.debian.local 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh
sub _irc_event_rpl_myinfo {
  my ($self, $msg) = @_;
  my @keys = qw(nick real_host version available_user_modes available_channel_modes);
  my $i    = 0;

  $self->{myinfo}{$_} = $msg->{params}[$i++] // '' for @keys;
  $self->emit(state => me => $self->{myinfo});
}

sub _irc_event_rpl_motdstart { }

sub _irc_event_authenticate {
  my ($self, $msg) = @_;
  $self->_irc_event_fallback($msg);
  return unless $msg->{raw_line} =~ m!AUTHENTICATE \+$!;

  my ($mech, $url) = ($self->_sasl_mechanism, $self->url);
  if ($mech eq 'EXTERNAL') {
    $self->_write(sprintf "AUTHENTICATE %s\r\n", $url->username || $self->user->email);
  }
  elsif ($mech eq 'PLAIN') {
    my @auth = grep {length} $url->query->param('authname') || $url->username, $url->username,
      $url->password;
    $self->_write(sprintf "AUTHENTICATE %s\r\n", b64_encode join "\0", @auth) if @auth == 3;
  }
}

sub _irc_event_rpl_channelmodeis {
  my ($self, $msg) = @_;
  my @params = @{$msg->{params}};
  shift @params unless $params[0] =~ $CHANNEL_RE;
  $self->_notice("$params[0] has mode $params[1].");
}

sub _irc_event_rpl_notopic {
  my ($self, $msg) = @_;
  $self->_irc_event_rpl_topic({%$msg, params => [$msg->{params}[0], $msg->{params}[0], '']});
}

sub _irc_event_rpl_topic {
  my ($self, $msg) = @_;
  return unless my $conversation = $self->get_conversation($msg->{params}[1]);
  return if $conversation->topic eq $msg->{params}[2];
  $self->emit(state => frozen => $conversation->topic($msg->{params}[2])->TO_JSON);
}

sub _irc_event_rpl_umodeis {
  my ($self, $msg) = @_;

  $self->_is_current_nick($msg->{params}[0])
    ? $self->_notice("You ($msg->{params}[0]) have mode $msg->{params}[1].")
    : $self->_notice("$msg->{params}[0] has mode $msg->{params}[1].");
}

# :hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
sub _irc_event_rpl_welcome {
  my ($self, $msg) = @_;

  $self->{failed_to_connect} = 0;
  $self->{myinfo}{real_host} ||= $msg->{prefix};
  $self->{myinfo}{nick} = $msg->{params}[0];
  $self->_message($msg->{params}[1]);   # Welcome to the debian Internet Relay Chat Network superman
  $self->emit(state => me => $self->{myinfo});

  my @commands = (
    (grep {/\S/} @{$self->on_connect_commands}),
    map {
          $_->is_private ? "/ISON $_->{name}"
        : $_->password   ? "/JOIN $_->{name} $_->{password}"
        : "/JOIN $_->{name}"
    } sort { $a->id cmp $b->id } @{$self->conversations}
  );

  Scalar::Util::weaken($self);
  my $write;
  $write = sub {
    return unless $self and @commands;
    my $command = shift @commands;
    $command =~ m!^/sleep\s+(\d+\.?\d*)!i
      ? Mojo::IOLoop->timer($1, $write)
      : $self->send_p('', $command)->finally($write);
  };
  $self->$write;
}

sub _irc_event_topic {
  my ($self, $msg) = @_;
  my ($nick, $user, $host) = IRC::Utils::parse_user($msg->{prefix});
  $self->_irc_event_rpl_topic({%$msg, params => [$nick, $msg->{params}[0], $msg->{params}[1]]});
}

# Ignore these events
sub _irc_event_rpl_namreply     { }
sub _irc_event_rpl_topicwhotime { }

sub _is_current_nick { lc $_[0]->nick eq lc $_[1] }

sub _make_ctcp_string {
  my $self = shift;
  local $_ = join ' ', @_;
  s/([\012\015\0\cP])/\cP$CTCP_QUOTE{$1}/g;
  s/\001/\\a/g;
  return ":\001${_}\001";
}

sub _make_default_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;
  return $p->resolve($res);
}

sub _make_invalid_target_p {
  my ($self, $target) = @_;

  # err_norecipient and err_notexttosend
  return Mojo::Promise->reject('Cannot send without target.')
    if !$$target
    or !($$target = trim $$target);
  return Mojo::Promise->reject('Cannot send message to target with spaces or comma.')
    if $$target =~ /[,\s]/;
  return;
}

sub _make_ison_response {
  my ($self, $msg, $res, $p) = @_;    # No need to get ($res, $p) here
  $msg->{ison} ||= {map { (lc($_) => $_) } split /\s+/, +($msg->{params}[1] || '')};
  $res->{online} = $msg->{ison}{lc($res->{nick})} ? true : false;

  my $conversation = $self->get_conversation($res->{nick});
  $self->emit(state => frozen => $conversation->frozen('')->TO_JSON) if $conversation;

  $p->resolve($res);
}

sub _make_join_response {
  my ($self, $msg, $res, $p) = @_;

  if ($msg->{command} eq '470') {
    $self->_notice("Forwarding $msg->{params}[1] to $msg->{params}[2].");
    return $self->_send_join_p("$msg->{params}[2]")->then(sub { $p->resolve($_[0]) });
  }
  if ($msg->{command} eq 'err_badchannelkey') {
    my $conversation = $self->conversation({name => $msg->{params}[1]});
    $self->emit(state => frozen => $conversation->frozen('Invalid password.')->TO_JSON);
    return $p->reject($msg->{params}[2]);
  }
  if ($msg->{command} eq 'err_inviteonlychan') {
    my $conversation = $self->conversation({name => $msg->{params}[1]});
    $self->emit(
      state => frozen => $conversation->frozen('This channel requires an invitation.')->TO_JSON);
    return $p->reject($msg->{params}[2]);
  }

  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;

  return $self->_make_users_response($msg, $res->{participants} ||= [])
    if $msg->{command} eq 'rpl_namreply';
  return $res->{topic}    = $msg->{params}[2] if $msg->{command} eq 'rpl_topic';
  return $res->{topic_by} = $msg->{params}[2] if $msg->{command} eq 'rpl_topicwhotime';

  if ($msg->{command} eq 'rpl_endofnames') {
    $res->{topic}    //= '';
    $res->{topic_by} //= '';
    $res->{users} ||= {};
    $p->resolve($res);
  }
}

sub _make_mode_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_! or $msg->{command} eq '697';

  $msg->{handled} = 1;
  if ($msg->{command} eq 'mode') {
    $res->{from}         = IRC::Utils::parse_user($msg->{prefix});
    $res->{mode}         = $msg->{params}[1] // '';
    $res->{mode_changed} = 1;
    $res->{nick}         = $msg->{params}[2] if $res->{mode} =~ /(o|v)$/ and $msg->{params}[2];
    $res->{target}       = $msg->{params}[0];
    return $p->resolve($res);
  }
  if ($msg->{command} =~ m!^rpl_endof(\w+list)!) {
    $res->{$1} ||= [];
    return $p->resolve($res);
  }
  if ($msg->{command} =~ /^rpl_(\w+list)$/) {
    push @{$res->{$1}},
      {by => $msg->{params}[3] // '', mask => $msg->{params}[2], ts => $msg->{params}[4] || 0};
  }
  if ($msg->{command} eq 'rpl_channelmodeis') {
    my @params = @{$msg->{params}};
    shift @params unless $params[0] =~ $CHANNEL_RE;
    @$res{qw(target mode)} = (shift @params, shift @params);
    return $p->resolve($res);
  }
  if ($msg->{command} eq 'rpl_umodeis') {
    @$res{qw(target mode)} = @{$msg->{params}};
    return $p->resolve($res);
  }
}

sub _make_names_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;
  return $p->resolve($res)              if $msg->{command} eq 'rpl_endofnames';
  return $self->_make_users_response($msg, $res->{participants} ||= [])
    if $msg->{command} eq 'rpl_namreply';
}

sub _make_oper_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;
  $self->{myinfo}{server_op} = true;
  $self->emit(state => me => $self->{myinfo});
  return $p->resolve($self->{myinfo});
}

sub _make_part_response {
  my ($self, $msg, $res, $p) = @_;
  $self->_remove_conversation(delete $res->{target})->save_p if $res->{target};

  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;
  return $p->resolve($res);
}

sub _make_topic_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;

  $res->{topic} = '' if $msg->{command} eq 'rpl_notopic';
  $res->{topic} = $msg->{params}[2] // '' if $msg->{command} eq 'rpl_topic';
  $res->{topic} = $msg->{params}[1] // '' if $msg->{command} eq 'topic';
  $p->resolve($res);

  my $conversation = $self->get_conversation($msg->{params}[0]);
  $self->emit(state => frozen => $conversation->topic($res->{topic})->TO_JSON)
    if $conversation and $conversation->topic ne $res->{topic};
}

sub _make_whois_response {
  my ($self, $msg, $res, $p) = @_;
  return $p->reject($msg->{params}[-1]) if $msg->{command} =~ m!^err_!;
  return $p->resolve($res)              if $msg->{command} eq 'rpl_endofwhois';

  return $res->{away}     = true                         if $msg->{command} eq 'rpl_away';
  return $res->{idle_for} = 0 + ($msg->{params}[2] // 0) if $msg->{command} eq 'rpl_whoisidle';
  return @$res{qw(server server_info)} = @{$msg->{params}}[2, 3]
    if $msg->{command} eq 'rpl_whoisserver';
  return @$res{qw(nick user host name)} = @{$msg->{params}}[1, 2, 3, 5]
    if $msg->{command} eq 'rpl_whoisuser';

  if ($msg->{command} eq '276') {
    $res->{fingerprint} = $1 if $msg->{raw_line} =~ m!fingerprint\s(\S+)!;
    $res->{secure}      = true;
  }
  if ($msg->{command} eq 'rpl_whoischannels') {
    for (split /\s+/, $msg->{params}[2] || '') {
      my ($mode, $channel) = $self->_parse_mode($_);
      $res->{channels}{$channel} = {mode => $mode};
    }
  }
}

sub _make_users_response {
  my ($self, $msg, $users) = @_;

  for (split /\s+/, $msg->{params}[3]) {
    my ($mode, $nick) = $self->_parse_mode($_);
    push @$users, {nick => $nick, mode => $mode};
  }
}

sub _message {
  my ($self, $message) = (shift, shift);
  my $from = $self->{myinfo}{real_host} || $self->id;
  $self->emit(
    message => $self->messages,
    {from => $from, highlight => false, type => 'private', @_, message => $message, ts => time},
  );
}

sub _message_type {
  return 'private' if $_[0]->{command} =~ /privmsg/i;
  return 'action'  if $_[0]->{command} =~ /action/i;
  return 'notice';
}

sub _parse {
  state $parser = Parse::IRC->new(ctcp => 1);
  return $parser->parse($_[1]);
}

sub _parse_mode {
  state $modes = {'%' => 'h', '&' => 'a', '+' => 'v', '@' => 'o', '~' => 'q'};
  return $_[1] =~ m!^([%&+@~])(.+)! ? ($modes->{$1}, $2) : ('', $_[1]);
}

sub _periodic_events {
  my $self = shift;
  my $tid;

  Scalar::Util::weaken($self);
  $tid = $self->{periodic_tid} //= Mojo::IOLoop->recurring(
    PERIDOC_INTERVAL,
    sub {
      return shift->remove($tid) unless $self;

      # Save unread count and other potential changes
      $self->save_p;

      # Try to get the nick you want
      my $nick = $self->url->query->param('nick');
      $self->_write("NICK $nick\r\n") if $nick and !$self->_is_current_nick($nick);

      # Keep the connection alive
      $self->_write("PING $self->{myinfo}{real_host}\r\n") if $self->{myinfo}{real_host};
    }
  );
}

sub _sasl_mechanism {
  my $self = shift;
  my $mech = uc($self->url->query->param('sasl') || '');
  return $mech =~ m!^(EXTERNAL|PLAIN)$! ? $mech : '';
}

sub _send_clear_p {
  my ($self, $what, $target) = @_;

  if (!$what or $what ne 'history' or !$target) {
    return Mojo::Promise->reject(
      'WARNING! /clear history [name] will delete all messages in the backend!');
  }

  my $conversation = $self->get_conversation($target);
  return $target
    ? $self->user->core->backend->delete_messages_p($conversation)
    : Mojo::Promise->reject('Unknown conversation.');
}

sub _send_ison_p {
  my ($self, $target) = @_;
  return Mojo::Promise->reject('Cannot send without target.') unless $target;
  return $self->_write_and_wait_p(
    "ISON $target", {nick => $target},
    rpl_ison => {},
    '_make_ison_response',
  );
}

sub _send_join_p {
  my ($self,            $command)  = @_;
  my ($conversation_id, $password) = (split(/\s/, ($command || ''), 2), '', '');

  return $self->_send_query_p($conversation_id)->then(
    sub {
      my $conversation = shift;
      $conversation->password($password) if $conversation and length $password;
      return $conversation->TO_JSON      if $command =~ m!^\w!;  # A bit more sloppy than is_private
      return !$conversation->frozen ? $conversation->TO_JSON : $self->_write_and_wait_p(
        "JOIN $command", {conversation_id => lc $conversation_id},
        470                 => {1 => $conversation_id},          # Link channel
        479                 => {1 => $conversation_id},          # Illegal channel name
        err_badchanmask     => {1 => $conversation_id},
        err_badchannelkey   => {1 => $conversation_id},
        err_bannedfromchan  => {1 => $conversation_id},
        err_channelisfull   => {1 => $conversation_id},
        err_inviteonlychan  => {1 => $conversation_id},
        err_nosuchchannel   => {1 => $conversation_id},
        err_toomanychannels => {1 => $conversation_id},
        err_toomanytargets  => {1 => $conversation_id},
        err_unavailresource => {1 => $conversation_id},
        rpl_endofnames      => {1 => $conversation_id},
        rpl_namreply        => {1 => $conversation_id},
        rpl_topic           => {2 => $conversation_id},
        rpl_topicwhotime    => {1 => $conversation_id},
        '_make_join_response',
      );
    },
    sub {
      return $self->_write_p("JOIN $command\r\n");
    }
  );
}

sub _send_kick_p {
  my ($self, $target, $command) = @_;
  my ($nick, $reason) = split /\s/, $command, 2;

  for my $t ($target, $nick) {
    my $invalid_target_p = $self->_make_invalid_target_p(\$t);
    return $invalid_target_p if $invalid_target_p;
  }

  my $cmd = "KICK $target $nick";
  $cmd .= " :$reason" if length $reason;

  return $self->_write_and_wait_p(
    $cmd, {},
    err_nosuchchannel    => {1 => $target},
    err_nosuchnick       => {1 => $nick},
    err_badchanmask      => {1 => $target},
    err_chanoprivsneeded => {1 => $target},
    err_usernotinchannel => {1 => $nick},
    err_notonchannel     => {1 => $target},
    kick                 => {0 => $target, 1 => $nick},
    '_make_default_response',
  );
}

sub _send_list_p {
  my ($self, $extra) = @_;
  return Mojo::Promise->reject('Not connected.') if $self->state ne 'connected';

  my $store = $self->_available_conversations;
  my @found;

  # Refresh conversation list
  if ($extra =~ m!\brefresh\b! or !$store->{ts}) {
    $store->{conversations} = {};
    $store->{done}          = false;
    $store->{ts}            = time;
    $self->_write("LIST\r\n");
  }

  # Search for a specific channel - only works for cached channels
  # IMPORTANT! Make sure the filter cannot execute code inside the regex!
  if ($extra =~ m!/(\W?[\w-]+)/(\S*)!) {
    my ($filter, $re_modifiers, $by, @by_name, @by_topic) = ($1, $2);

    $re_modifiers = 'i' unless $re_modifiers;
    $by           = $re_modifiers =~ s!([nt])!! ? $1 : 'nt';    # name or topic
    $filter       = qr{(?$re_modifiers:$filter)} if $filter;    # (?i:foo_bar)

    for my $conversation (sort { $a->{name} cmp $b->{name} } values %{$store->{conversations}}) {
      push @by_name,  $conversation and next if $conversation->{name}  =~ $filter;
      push @by_topic, $conversation and next if $conversation->{topic} =~ $filter;
    }

    @found = ($by =~ /n/ ? @by_name : (), $by =~ /t/ ? @by_topic : ());
  }
  else {
    @found = sort { $b->{n_users} <=> $a->{n_users} } values %{$store->{conversations}};
  }

  return Mojo::Promise->resolve({
    n_conversations => int(keys %{$store->{conversations}}),
    conversations   => [splice @found, 0, 200],
    done            => $store->{done},
  });
}

sub _send_message_p {
  my $self    = shift;
  my $target  = shift;
  my $message = shift // '';

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;

  my $messages = $self->_split_message($message);
  return Mojo::Promise->reject('Cannot send empty message.') unless @$messages;

  if (MAX_BULK_MESSAGE_SIZE <= @$messages or MAX_MESSAGE_LENGTH < length $messages->[0]) {
    return $self->user->core->backend->emit_to_class_p(message_to_paste => $self, $message)
      ->then(sub { $self->_send_message_p($target, shift->to_message) });
  }

  for (@$messages) {
    $_ = $self->_parse(sprintf ':%s PRIVMSG %s :%s', $self->nick, $target, $_);
    return Mojo::Promise->reject('Unable to construct PRIVMSG.') unless ref $_;
  }

  # Seems like there is no way to know if a message is delivered
  # Instead, there might be some errors occuring if the message had issues:
  # err_cannotsendtochan, err_nosuchnick, err_notoplevel, err_toomanytargets,
  # err_wildtoplevel, irc_rpl_away

  my $nick = $self->nick;
  my $user = $self->url->username || $nick;
  return Mojo::Promise->all(map { $self->_write_p($_->{raw_line}) } @$messages)->then(sub {
    for my $msg (@$messages) {
      $msg->{prefix} = sprintf '%s!%s@%s', $nick, $user, $self->url->host;
      $msg->{event}  = lc $msg->{command};
      $self->_irc_event_privmsg($msg);
    }
    return {};
  });
}

sub _send_mode_p {
  my ($self, $target) = (shift, shift);
  my @args = split /\s+/, shift;

  $target ||= shift @args // '';
  $target = shift @args if $args[0] and $args[0] =~ $CHANNEL_RE;
  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;

  my $res = {};
  $res->{banlist}    = [] if $args[0] and $args[0] eq 'b';
  $res->{exceptlist} = [] if $args[0] and $args[0] eq 'e';

  unshift @args, $target if $target;
  return $self->_write_and_wait_p(
    join(' ', MODE => @args), $res,
    err_chanoprivsneeded => {1 => $target},
    err_keyset           => {1 => $target},
    err_needmoreparams   => {1 => $target},
    err_nochanmodes      => {1 => $target},
    err_nosuchchannel    => {1 => $target},
    err_unknownmode      => {1 => $target},
    err_usernotinchannel => {1 => $target},
    mode                 => {0 => $target},
    rpl_endofbanlist     => {1 => $target},
    rpl_endofexceptlist  => {1 => $target},
    rpl_endofinvitelist  => {1 => $target},
    rpl_channelmodeis    => {1 => $target},
    rpl_banlist          => {1 => $target},
    rpl_exceptlist       => {1 => $target},
    rpl_invitelist       => {1 => $target},
    rpl_umodeis          => {1 => $target},
    rpl_uniqopis         => {1 => $target},
    697                  => {0 => $target},
    '_make_mode_response',
  );
}

sub _send_names_p {
  my ($self, $target) = @_;

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;
  return $self->_write_and_wait_p(
    "NAMES $target", {conversation_id => lc $target},
    err_toomanymatches => {1 => $target},
    rpl_endofnames     => {1 => $target},
    rpl_namreply       => {2 => $target},
    timeout            => 30,
    '_make_names_response',
  );
}

sub _send_nick_p {
  my ($self, $nick) = @_;
  return Mojo::Promise->reject('Missing or invalid nick.') unless $nick;

  $self->{myinfo}{nick} = $nick;
  $self->url->query->param(nick => $nick);
  $self->emit(state => me => $self->{myinfo});
  return $self->_write_p("NICK $nick\r\n") if $self->{stream};
  return Mojo::Promise->resolve({});
}

sub _send_oper_p {
  my ($self, $target, $message) = @_;

  return $self->_write_and_wait_p(
    "OPER $message", {},
    err_needmoreparams => {},
    err_nooperhost     => {},
    err_passwdmismatch => {},
    rpl_youreoper      => {},
    '_make_oper_response',
  );
}

sub _send_part_p {
  my ($self, $target) = @_;

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;

  my $conversation = $self->get_conversation($target);
  return $self->_remove_conversation($target)->save_p->then(sub { +{} })
    if $conversation and $conversation->is_private;

  return $self->_remove_conversation($target)->save_p->then(sub { +{} })
    if $self->state eq 'disconnected';

  return $self->_write_and_wait_p(
    "PART $target", {target => $target},
    479               => {1 => $target},   # Illegal channel name
    err_nosuchchannel => {1 => $target},   # :hybrid8.debian.local 403 nick #convos :No such channel
    err_notonchannel  => {1 => $target},
    part              => {0 => $target},
    '_make_part_response',
  );
}

sub _send_query_p {
  my ($self, $target) = @_;
  my $p = Mojo::Promise->new;

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;

  # Already in the conversation
  ($target) = split /\s/, $target, 2;
  my $conversation = $self->get_conversation($target);
  return $p->resolve($conversation) if $conversation and !$conversation->frozen;

  # New conversation. Note that it needs to be frozen, so join_channel will be issued
  $conversation ||= $self->conversation({name => $target});
  $conversation->frozen('Not active in this room.')
    if !$conversation->is_private and !$conversation->frozen;
  $self->emit(state => frozen => $conversation->TO_JSON);
  return $p->resolve($conversation);
}

sub _send_topic_p {
  my ($self, $target, $topic) = @_;

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;

  my $cmd = "TOPIC $target";
  $cmd .= " :$topic" if length $topic;
  return $self->_write_and_wait_p(
    $cmd, {conversation_id => $target, topic => $topic // ''},
    err_chanoprivsneeded => {1 => $target},
    err_nochanmodes      => {1 => $target},
    err_notonchannel     => {1 => $target},
    rpl_notopic          => {1 => $target},
    rpl_topic            => {1 => $target},
    topic                => {0 => $target},
    '_make_topic_response',
  );
}

sub _send_whois_p {
  my ($self, $target) = @_;

  my $invalid_target_p = $self->_make_invalid_target_p(\$target);
  return $invalid_target_p if $invalid_target_p;
  return $self->_write_and_wait_p(
    "WHOIS $target",
    {away => false, channels => {}, name => '', nick => $target, server => '', user => ''},
    276               => {1 => $target},
    err_nosuchnick    => {1 => $target},
    err_nosuchserver  => {1 => $target},
    rpl_away          => {1 => $target},
    rpl_endofwhois    => {1 => $target},
    rpl_whoischannels => {1 => $target},
    rpl_whoisidle     => {1 => $target},
    rpl_whoisserver   => {1 => $target},
    rpl_whoisuser     => {1 => $target},
    '_make_whois_response',
  );
}

sub _set_wanted_state_p {
  my ($self, $state) = @_;
  $self->wanted_state($state);
  $self->user->core->connect($self, '') if $state eq 'connected';
  $self->disconnect_p                   if $state eq 'disconnected';
  return Mojo::Promise->resolve({});
}

sub _split_message {
  my ($self, $message) = @_;
  return [split /\n\r?/, $message] if length($message) < MAX_MESSAGE_LENGTH;

  my @messages;
  while (length $message) {
    $message =~ s!^\r*\n*!!s;
    $message =~ s!^(.*)!!m;
    my $line = $1;

    # No need to check anymore, since we are going to make a paste anyways
    return \@messages if @messages >= MAX_BULK_MESSAGE_SIZE;

    # Line is short
    if (length($line) < MAX_MESSAGE_LENGTH) {
      push @messages, $line;
      next;
    }

    # Split long lines into multiple lines
    my @chunks = split /(\s)/, $line;
    $line = '';
    while (@chunks) {
      my $chunk = shift @chunks;

      # Force break, in case it's just one long word
      if (MAX_MESSAGE_LENGTH < length $chunk) {
        unshift @chunks, substr($chunk, 0, MAX_MESSAGE_LENGTH - 1, ''), $chunk;
        next;
      }

      $line .= $chunk;
      my $next = @chunks && $chunks[0] || '';
      if (MAX_MESSAGE_LENGTH < length "$line$next") {
        push @messages, trim $line;
        $line = '';
      }
    }

    # Add remaining chunk
    push @messages, trim $line if length $line;
  }

  return \@messages;
}

sub _stream {
  my ($self, $loop, $err, $stream) = @_;
  $self->SUPER::_stream($loop, $err, $stream);
  return if $err;

  my $url = $self->url;
  if (my $password = $self->_web_irc_password) {
    my $remote_address  = $url->query->param('remote_address')               || '127.0.0.1';
    my $remote_hostname = gethostbyaddr(inet_aton($remote_address), AF_INET) || $remote_address;
    $self->_write(sprintf "WEBIRC %s %s %s %s\r\n",
      $password, 'convos', $remote_hostname, $remote_address);
  }

  $self->_write("CAP LS\r\n");
  $self->_write(sprintf "PASS %s\r\n", $url->password)
    if length $url->password and !$self->_sasl_mechanism;

  my $nick = $self->nick;
  $self->_write("NICK $nick\r\n");

  my $mode     = $url->query->param('mode') || 0;
  my $user     = $url->username             || $nick;
  my $realname = $url->query->param('realname');
  $realname = $realname ? "$realname via $CONVOS_URL" : $CONVOS_URL;

  $user =~ s/^[^a-zA-Z0-9]/x/;
  $self->_write("USER $user $mode * :$realname\r\n");
}

sub _stream_on_read {
  my ($self, $stream, $buf) = @_;
  $self->{buffer} .= Unicode::UTF8::decode_utf8($buf, sub {$buf});

CHUNK:
  while ($self->{buffer} =~ s/^([^\015\012]+)[\015\012]//m) {
    $self->_debug('>>> %s', term_escape $1) if DEBUG;
    my $msg = $self->_parse($1);
    next unless $msg->{command};

    $msg->{command} = IRC::Utils::numeric_to_name($msg->{command}) || $msg->{command}
      if $msg->{command} =~ /^\d+$/;
    $msg->{command} = lc $msg->{command};
    my $method = "_irc_event_$msg->{command}";

    # @wait_for is to avoid "Use of freed value in iteration"
    my @wait_for = values %{$self->{wait_for}{$msg->{command}} || {}};
    my $handled  = 0;

  WAIT_FOR:
    for (@wait_for) {
      my ($res, $p, $rules, $make_response_method) = @$_;

      for my $k (keys %$rules) {
        my $v = $k =~ /^\d/ ? $msg->{params}[$k] : $msg->{$k};
        next WAIT_FOR unless lc $v eq lc $rules->{$k};
      }

      $self->_debug('->%s(...)', $make_response_method) if DEBUG;
      $self->$make_response_method($msg, $res, $p);
      $handled++;
    }

    if (my $cb = $self->can($method)) {
      $self->_debug('->%s(...)', $method) if DEBUG;
      $self->$cb($msg);
    }
    elsif (!$handled) {
      $self->_debug('->%s(...) (fallback)', $method) if DEBUG;
      $self->_irc_event_fallback($msg);
    }

    $self->emit(irc_message => $msg)->emit($method => $msg) if IS_TESTING;
  }
}

sub _web_irc_password {
  my $name = shift->name;
  state $pw = {};
  return $pw->{$name} if $pw->{$name};
  my $key = sprintf 'CONVOS_WEBIRC_PASSWORD_%s', uc $name;
  $key =~ s!\W!_!g;
  return $pw->{$key} = Mojo::URL->new($ENV{$key} || '');
}

# This method is used to write a message to the IRC server and wait for a
# response in the form of one or more events.
#
# Example:
#
# my $promise = $self->_write_and_wait_p(
#
#   # First argument is the command to write to the IRC server
#   "NAMES #convos",
#
#   # Second argument is the initial value of $res
#   {conversation_id => "#convos"},
#
#   # The next arguments are key/value pairs of IRC::Utils event names and
#   # conditions to determine if the event was generated in response to this
#   # command. The number refers to an item in the "params" array from
#   # Parse::IRC::parse_irc(), and maps to the expected value of that param
#   # (Use perl ./script/parse-irc-message.pl to see an example struture)
#   err_toomanymatches => {1 => "#convos"},
#   rpl_endofnames     => {1 => "#convos"},
#   rpl_namreply       => {2 => "#convos"},
#
#   # "timeout" is the max number of seconds we should wait for a reply
#   # before rejecting the $promise
#   timeout => 30,
#
#   # The last argument is the name of a method to call to process an event that
#   # matches one of those defined above
#   '_make_names_response',
# )->then(sub {
#    my $res = shift; {conversation_id => "#convos", ...}
# });
sub _write_and_wait_p {
  my $make_response_method = pop;
  my ($self, $cmd, $res, %events) = @_;

  my @names = keys %events;
  my $id    = ++$self->{wait_for_id};
  my $p     = Mojo::Promise->new;
  $self->{wait_for}{$_}{$id} = [$res, $p, $events{$_}, $make_response_method] for @names;

  return Mojo::Promise->race(
    Mojo::Promise->timeout($events{timeout} || 60),
    Mojo::Promise->all($p, $self->_write_p($cmd))
  )->then(sub {
    return $_[0][0];    # Only interested in the response from $p
  })->finally(sub {
    delete $self->{wait_for}{$_}{$id} for @names;
  });
}

sub DESTROY {
  my $tid = $_[0]->{periodic_tid};
  Mojo::IOLoop->remove($tid) if $tid;
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

=head2 disconnect_p

See L<Convos::Core::Connection/disconnect_p>.

=head2 send_p

See L<Convos::Core::Connection/send>.

=head1 SEE ALSO

L<Convos::Core>.

=cut
