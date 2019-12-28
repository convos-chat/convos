#!perl
use lib '.';
use t::Helper;
use Mojo::IOLoop;
use Convos::Core;

$ENV{CONVOS_CONNECT_DELAY} = 0.2;
my $core = Convos::Core->new(backend => 'Convos::Core::Backend');
$core->start;

my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my ($err, $res);

my @state;
$connection->on(state => sub { push @state, $_[2]->{state} if $_[1] eq 'connection' });

ok !$connection->get_dialog('#convos'), 'convos channel does not exist';

note 'invalid input';
for my $cmd (
  ['#convos',   '/kick'],               # KICK
  ['',          '/names'],              # NAMES
  ['',          '/say'],                # SAY
  ['',          '/topic'],              # TOPIC get
  ['',          '/topic New topic'],    # TOPIC set
  ['#whatever', '/ison'],               # ISON
  ['#whatever', '/join'],               # JOIN
  ['#whatever', '/msg'],                # MSG
  ['#whatever', '/whois'],              # WHOIS
  )
{
  $connection->send_p(@$cmd)->catch(sub { $err = shift })->$wait_success($cmd->[1]);
  like $err, qr{Cannot send without target.}, "$cmd->[1] - missing target";
}

# /join #convos below will create the #convos dialog
ok !$connection->get_dialog('#convos'), 'convos dialog does not exist';

note 'not connected';
for my $cmd (
  ['#convos',   '/kick superwoman Not cool'],       # KICK
  ['#convos',   '/mode +o superwoman'],             # MODE
  ['#convos',   '/say /me is a command'],           # SAY
  ['#convos',   '/close'],                          # CLOSE
  ['#convos',   '/close superwoman'],               # CLOSE
  ['#convos',   '/names'],                          # NAMES
  ['#convos',   '/topic'],                          # TOPIC get
  ['#convos',   '/topic New topic'],                # TOPIC set
  ['#whatever', '/ison superwoman'],                # ISON
  ['#whatever', '/join #convos s3cret'],            # JOIN
  ['#whatever', '/msg superwoman how are you?'],    # MSG
  ['#whatever', '/list'],                           # LIST
  ['#whatever', '/whois superwoman'],               # WHOIS
  )
{
  $connection->send_p(@$cmd)->catch(sub { $err = shift })->$wait_success($cmd->[1]);
  like $err, qr{Not connected.}, "$cmd->[1] - not connected";
}

$connection->send_p('', '/nick superduper')->$wait_success('nick');
is $connection->url->query->param('nick'), 'superduper', 'change nick offline';

ok !$connection->get_dialog('superwoman'), 'superwoman does not exist';
$connection->send_p('', '/query superwoman')->$wait_success('query');
ok $connection->get_dialog('superwoman'), 'superwoman exist';

note 'disconnect and connect';
my $irc_server = t::Helper->irc_server_connect($connection);
$connection->send_p('', '/disconnect')->$wait_success('disconnect');
$connection->send_p('', '/connect')->$wait_success('connect');
t::Helper->irc_server_messages(
  qr{NICK} => ['welcome.irc'],
  $connection, '_irc_event_rpl_welcome',
  qr{JOIN} => ['join-convos.irc'],
  $connection, '_irc_event_join',
);

note 'kick';
$connection->send_p('#nope', '/kick superwoman')->catch(sub { $err = shift })
  ->$wait_success(from_server => ":localhost 403 superman #nope :No such channel\r\n");
is $err, 'No such channel', 'kick #nope';

$res = $connection->send_p('#convos', '/kick superwoman')
  ->$wait_success(from_server => ":localhost KICK #convos superwoman :superman\r\n");
is_deeply($res, {}, 'kick response');

note 'mode';
$connection->send_p('#nope', '/mode superwoman')->catch(sub { $err = shift })
  ->$wait_success(qr{MODE} => ":localhost 461 superman #nope :Not enough parameters\r\n");
is $err, 'Not enough parameters', 'mode superwoman';

$res = $connection->send_p('#convos', '/mode')
  ->$wait_success(qr{MODE} => ":localhost 324 superman #convos +intu\r\n");
is_deeply($res, {mode => '+intu'}, 'mode response');

$res = $connection->send_p('#convos', '/mode +k secret')
  ->$wait_success(qr{MODE} => ":localhost MODE #convos +k :secret\r\n");
is_deeply($res, {}, 'mode +k response');

$res = $connection->send_p('#convos', '/mode b')->$wait_success(
  qr{MODE} =>
    ":localhost 367 superman #convos x!*@* superman!~superman@125-12-219-233.rev.home.ne.jp 1577498687\r\n",
  from_server => ":localhost 368 superman #convos :End of Channel Ban List\r\n",
);
is_deeply(
  $res,
  {
    banlist => [
      {
        by   => 'superman!~superman@125-12-219-233.rev.home.ne.jp',
        mask => 'x!*@*',
        ts   => 1577498687,
      },
    ],
  },
  'mode b response'
);

note 'names';
$res = $connection->send_p('#convos', '/names')
  ->$wait_success(from_server => [__PACKAGE__, 'names.irc']);
is_deeply(
  $res,
  {
    dialog_id    => '#convos',
    participants => [
      {nick => 'superwoman', mode => ''},
      {nick => 'superman',   mode => ''},
      {nick => 'robin',      mode => ''},
      {nick => 'batboy',     mode => ''},
      {nick => 'superboy',   mode => 'o'},
      {nick => 'robyn',      mode => 'v'},
    ],
  },
  'names response',
);

note 'topic';
$res = $connection->send_p('#convos', '/topic')
  ->$wait_success(from_server => ":localhost 331 superman #convos :No topic is set\r\n");
is_deeply($res, {dialog_id => '#convos', topic => ''}, 'topic');

$res = $connection->send_p('#convos', '/topic')
  ->$wait_success(from_server => ":localhost 332 superman #convos :cool topic\r\n");
is_deeply($res, {dialog_id => '#convos', topic => 'cool topic'}, 'topic');

$res = $connection->send_p('#convos', '/topic Some cool stuff')
  ->$wait_success(from_server => ":localhost TOPIC #convos :Some cool\r\n");
is_deeply($res, {dialog_id => '#convos', topic => 'Some cool'}, 'set topic');

note 'ison';
$res
  = Mojo::Promise->all(map { $connection->send_p('', "/ison $_") } qw(SuperBoy superwoman SUPERBAD))
  ->then(sub { [map { $_->[0] } @_] })
  ->$wait_success(from_server => ":localhost 303 test21362 :other SuperBoy superbad\r\n");
is_deeply(
  $res,
  [
    {nick => 'SuperBoy',   online => true},
    {nick => 'superwoman', online => false},
    {nick => 'SUPERBAD',   online => true},
  ],
  'ison'
);

note 'join';
$res = $connection->send_p('', '/join #redirected')->$wait_success(
  from_server             => [__PACKAGE__, 'join-redirected-1.irc'],
  qr{JOIN \#\#redirected} => [__PACKAGE__, 'join-redirected-2.irc'],
);
is_deeply($res, {dialog_id => '##redirected', topic => '', topic_by => '', users => {}}, 'join');

note 'list';
$res = $connection->send_p('', '/list')
  ->$wait_success(from_server => ":localhost 321 superman Channel :Users  Name\r\n");
is_deeply($res, {n_dialogs => 0, dialogs => [], done => false}, 'list empty');

t::Helper->irc_server_messages(
  from_server => ":localhost 322 superman #Test123 1 :[+nt]\r\n",
  $connection, '_irc_event_rpl_list',
  from_server => ":localhost 322 superman #convos 42 :[+nt] some cool topic\r\n",
  $connection, '_irc_event_rpl_list',
);
$res = $connection->send_p('', '/list')->$wait_success;
is_deeply(
  $res,
  {
    done      => false,
    n_dialogs => 2,
    dialogs   => [
      {dialog_id => '#convos',  name => '#convos',  n_users => 42, topic => 'some cool topic'},
      {dialog_id => '#test123', name => '#Test123', n_users => 1,  topic => ''},
    ],
  },
  'list dialogs',
);

t::Helper->irc_server_messages(
  from_server => ":localhost 323 superman :End of /LIST\r\n",
  $connection => '_irc_event_rpl_listend',
);
$res = $connection->send_p('', '/list')->$wait_success;
ok $res->{done}, 'list done';

note 'whois';
$res = $connection->send_p('', '/whois superwoman')
  ->$wait_success(qr{WHOIS}, [__PACKAGE__, 'whois-superwoman.irc']);
is_deeply(
  $res,
  {
    away        => false,
    channels    => {'#test123' => {mode => ''}, '#convos' => {mode => 'o'}},
    host        => 'irc.example.com',
    idle_for    => 17454,
    name        => 'Convos v10.01',
    nick        => 'superwoman',
    server      => 'localhost',
    server_info => 'ircd-hybrid 8.1-debian',
    user        => 'SuperWoman',
  },
  'whois'
);

note 'close and part';
$res = $connection->send_p('#convos', '/close superwoman')->$wait_success;
is_deeply($res, {}, 'close superwoman response');

$connection->send_p('#convos', '/close #foo')->catch(sub { $err = shift })
  ->$wait_success(qr{PART}, ":localhost 442 superman #foo :You are not on that channel\r\n");
is $err, 'You are not on that channel', 'close #foo';

$connection->dialog({name => '#convos'});
ok $connection->get_dialog('#convos'), 'has convos dialog';
$res = $connection->send_p('#convos', '/part')
  ->$wait_success(qr{PART} => ":localhost PART #convos\r\n");
is_deeply($res, {}, 'part #convos');
ok !$connection->get_dialog('#convos'), 'convos dialog was removed';

note 'unknown commands';
$connection->send_p('', '/foo')->catch(sub { $err = shift })->$wait_success;
like $err, qr{Unknown command}, 'Unknown command';

$connection->send_p('', '/raw FOO some stuff')->$wait_success(
  qr{FOO} => ":localhost 421 superman FOO :Unknown command\r\n",
  $connection, '_irc_event_err_unknowncommand',
);

note 'server disconnect';
my $id = $connection->{stream_id};
ok !!Mojo::IOLoop->stream($id), 'got stream';
$connection->once(state => sub { Mojo::IOLoop->stop });
$irc_server->emit('close_stream');
Mojo::IOLoop->start;
ok !Mojo::IOLoop->stream($id), 'stream was removed';

t::Helper->irc_server_messages(qr{NICK} => ['welcome.irc'], $connection, '_irc_event_rpl_welcome',);
isnt $connection->{stream_id}, $id, 'got new stream id';
ok !!Mojo::IOLoop->stream($connection->{stream_id}), 'got new stream';

is_deeply \@state, [qw(connected queued connected)], 'got correct state';

done_testing;

__DATA__
@@ join-redirected-1.irc
:localhost 470 superman #redirected ##redirected :Forwarding to another channel
@@ join-redirected-2.irc
:localhost 332 superman ##redirected :Used to be #redirected
:localhost 353 superman @ ##redirected :superwoman @superman
:localhost 366 superman ##redirected :End of /NAMES list.
@@ names.irc
:localhost 353 superman = #convos :superwoman superman robin
:localhost 353 superman = #convos :batboy @superboy +robyn
:localhost 366 superman #convos :End of /NAMES list.
@@ whois-superwoman.irc
:localhost 311 superman superwoman SuperWoman irc.example.com * :Convos v10.01
:localhost 319 superman superwoman :#test123 @#convos
:localhost 312 superman superwoman localhost :ircd-hybrid 8.1-debian
:localhost 338 superman superwoman 255.255.255.255 :actually using host
:localhost 317 superman superwoman 17454 1432930742 :seconds idle, signon time
:localhost 318 superman superwoman :End of /WHOIS list.
