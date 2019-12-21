#!perl
use lib '.';
use t::Helper;
use Mojo::IOLoop;
use Convos::Core;

my $core       = Convos::Core->new(backend => 'Convos::Core::Backend');
my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});

t::Helper->irc_server_connect($connection);
t::Helper->irc_server_messages(qr{NICK} => ['welcome.irc'], $connection, '_irc_event_rpl_welcome');

my (@messages, @state);
$connection->on(message => sub { push @messages, $_[2] });
$connection->on(state   => sub { push @state, [@_[1, 2]] });

note 'error handlers';
t::Helper->irc_server_messages(
  from_server => ":localhost 404 superman #nopechan :Cannot send to channel\r\n",
  $connection, '_irc_event_err_cannotsendtochan',
  from_server => ":localhost 421 superman cool_cmd :Unknown command\r\n",
  $connection, '_irc_event_err_unknowncommand',
  from_server => ":localhost 432 superman nopeman :Erroneous nickname\r\n",
  $connection, '_irc_event_err_erroneusnickname',
  from_server => ":localhost 433 superman nopeman :Nickname is already in use\r\n",
  $connection, '_irc_event_err_nicknameinuse',
  from_server => ":localhost PING irc.example.com\r\n",
  $connection, '_irc_event_ping',
  from_server => ":localhost PONG irc.example.com\r\n",
  $connection, '_irc_event_pong',
  from_server => ":superwoman!Superduper\@localhost QUIT :Gone to lunch\r\n",
  $connection, '_irc_event_quit',
);

is delete $_->{from}, 'irc-localhost', 'from irc-localhost' for @messages;
is delete $_->{type}, 'error',         'type error'         for @messages;
ok delete $_->{ts}, 'got timestamp' for @messages;

is_deeply(
  [map { $_->{message} } @messages],
  [
    'Cannot send to channel #nopechan.',
    'Unknown command: cool_cmd',
    'Invalid nickname nopeman.',
    'Nickname nopeman is already in use.',
  ],
  'got error messages',
);

is_deeply(
  \@state,
  [[quit => {message => 'Gone to lunch', nick => 'superwoman'}]],
  'got state changes',
);

t::Helper->irc_server_messages(
  'from_server' => ":supergirl!u2\@example.com PRIVMSG mojo_irc :\x{1}PING 1393007660\x{1}\r\n",
  $connection   => '_irc_event_ctcp_ping',
  qr{:\x01PING \d+\x01} => ":supergirl!u2\@example.com PRIVMSG mojo_irc :\x{1}TIME\x{1}\r\n",
  $connection           => '_irc_event_ctcp_time',
  qr{:\x01TIME\s}       => ":supergirl!u2\@example.com PRIVMSG mojo_irc :\x{1}VERSION\x{1}\r\n",
  $connection           => '_irc_event_ctcp_version',
  qr{:\x01VERSION Convos \d+\.\d+\x01} =>
    ":supergirl!u2\@example.com PRIVMSG superman :\x{1}ACTION msg1\x{1}\r\n",
  $connection => '_irc_event_ctcp_action',
);

@state = ();
$connection->dialog({name => '#convos'});
t::Helper->irc_server_messages(
  from_server =>
    ":localhost 004 superman hybrid8.debian.local hybrid-1:8.2.0+dfsg.1-2 DFGHRSWabcdefgijklnopqrsuwxy bciklmnoprstveIMORS bkloveIh\r\n",
  $connection, '_irc_event_rpl_myinfo',
  from_server => ":superwoman!sw\@localhost JOIN :#convos\r\n",
  $connection, '_irc_event_join',
  from_server => ":superwoman!sw\@localhost KICK #convos superwoman :superman\r\n",
  $connection, '_irc_event_kick',
  from_server => ":superman!sm\@localhost MODE #convos +i :superwoman\r\n",
  $connection, '_irc_event_mode',
  from_server => ":supergirl!sg\@localhost NICK :superduper\r\n",
  $connection, '_irc_event_nick',
  from_server => ":superduper!sd\@localhost PART #convos :I'm out\r\n",
  $connection, '_irc_event_part',
  from_server => ":superwoman!sw\@localhost TOPIC #convos :Too cool!\r\n",
  $connection, '_irc_event_topic',
);

cmp_deeply(
  \@state,
  bag(
    [join => {dialog_id => '#convos', nick => 'superwoman'}],
    [mode => {dialog_id => '#convos', from => 'superman', mode => '+i', nick => 'superwoman'}],
    [nick_change => {new_nick  => 'superduper', old_nick => 'supergirl'}],
    [part        => {dialog_id => '#convos',    message  => 'I\'m out', nick => 'superduper'}],
    [
      me => {
        available_channel_modes => 'bciklmnoprstveIMORS',
        available_user_modes    => 'DFGHRSWabcdefgijklnopqrsuwxy',
        nick                    => 'superman',
        real_host               => 'hybrid8.debian.local',
        version                 => 'hybrid-1:8.2.0+dfsg.1-2',
      }
    ],
    [
      part => {
        dialog_id => '#convos',
        kicker    => 'superwoman',
        message   => 'superman',
        nick      => 'superwoman',
      }
    ],
    [
      topic => {
        connection_id => 'irc-localhost',
        dialog_id     => '#convos',
        frozen        => '',
        last_active   => re(qr{^\d+-\d+-\d+}),
        last_read     => re(qr{^\d+-\d+-\d+}),
        name          => '#convos',
        topic         => 'Too cool!',
        unread        => 0,
      }
    ]
  ),
  'state changes',
) or diag explain \@state;

@messages = ();
t::Helper->irc_server_messages(
  from_server => ":localhost NOTICE AUTH :*** Found your hostname\r\n",
  $connection, '_irc_event_notice',
);
cmp_deeply(
  \@messages,
  bag(
    map {
      +{
        highlight => false,
        from      => 'irc-localhost',
        message   => $_,
        ts        => re(qr{^\d+}),
        type      => 'notice',
      };
    } '*** Found your hostname'
  ),
  'got noticed',
) or diag explain \@messages;

# sub _irc_event_mode {

done_testing;
