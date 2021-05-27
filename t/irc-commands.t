#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;
use Mojo::IOLoop;
use Convos::Core;

$ENV{CONVOS_CONNECT_DELAY} = 0.2;
my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new(backend => 'Convos::Core::Backend');
$core->start;

my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({url => 'irc://localhost'});
my ($err, $p, $res);

my @state;
$connection->url($server->url);
$connection->on(state => sub { push @state, [@_[1, 2]] });

ok !$connection->get_conversation('#convos'), 'convos channel does not exist';

note 'invalid input';
for my $cmd (
  ['#convos',   '/kick'],               # KICK
  ['',          '/names'],              # NAMES
  ['',          '/say'],                # SAY
  ['',          '/topic'],              # TOPIC get
  ['',          '/topic New topic'],    # TOPIC set
  ['#whatever', '/msg'],                # MSG
  ['#whatever', '/whois'],              # WHOIS
  )
{
  $connection->send_p(@$cmd)->catch(sub { $err = shift })->$wait_success($cmd->[1]);
  like $err, qr{Cannot send without target.}, "$cmd->[1] - missing target";
}

# /join #convos below will create the #convos conversation
ok !$connection->get_conversation('#convos'), 'convos conversation does not exist';

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
  ['whatever',  '/ison'],                           # ISON
  ['#whatever', '/jOIN #Convos s3cret'],            # JOIN
  ['#whatever', '/msg superwoman how are you?'],    # MSG
  ['#whatever', '/list'],                           # LIST
  ['#whatever', '/whois superwoman'],               # WHOIS
  )
{
  $connection->send_p(@$cmd)->catch(sub { $err = shift })->$wait_success($cmd->[1]);
  like $err, qr{Not connected.}, "$cmd->[1] - not connected";
}

is $connection->get_conversation('#convos')->password, 's3cret', 'password is set';

$connection->send_p('', '/nick superduper')->$wait_success('nick');
is $connection->url->query->param('nick'), 'superduper', 'change nick offline';

ok !$connection->get_conversation('superwoman'), 'superwoman does not exist';
$connection->send_p('', '/query superwoman ')->$wait_success('query');
ok $connection->get_conversation('superwoman'), 'superwoman exist';

cmp_deeply(
  \@state,
  [
    [frozen => superhashof({conversation_id => '#convos', frozen => 'Not active in this room.'})],
    [me     => {authenticated => false, capabilities => {}, nick => 'superduper'}],
    [frozen => superhashof({conversation_id => 'superwoman', frozen => ''})],
  ],
  'nick and frozen event so far'
) or diag explain \@state;

note 'disconnect and connect';
$connection->send_p('', '/disconnect')->$wait_success('disconnect command');
$server->auto_connect(0)->client($connection)->server_event_ok('_irc_event_nick')
  ->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')
  ->server_write_ok(['join-convos.irc'])->client_event_ok('_irc_event_join');
$connection->send_p('', '/connect')->$wait_success('connect command');
$server->process_ok('connect');

note 'kick';
$server->server_event_ok('_irc_event_kick')
  ->server_write_ok(":localhost 403 superman #nope :No such channel\r\n");
$connection->send_p('#nope', '/kick superwoman')->catch(sub { $err = shift })->$wait_success;
$server->processed_ok;
is $err, 'No such channel', 'kick #nope';

$server->server_event_ok('_irc_event_kick')
  ->server_write_ok(":localhost KICK #convos superwoman :superman\r\n");
$res = $connection->send_p('#convos', '/kick superwoman')->$wait_success;
$server->processed_ok;
is_deeply($res, {}, 'kick response');

note 'mode';
$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost 461 superman #nope :Not enough parameters\r\n");
$connection->send_p('#nope', '/mode superwoman')->catch(sub { $err = shift })->$wait_success;
$server->processed_ok;
is $err, 'Not enough parameters', 'mode superwoman';

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost 324 superman #convos +intu\r\n");
$res = $connection->send_p('#convos', '/mode')->$wait_success;
$server->processed_ok;
is_deeply($res, {mode => '+intu', target => '#convos'}, 'mode response');

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost MODE #convos +k :secret\r\n");
$res = $connection->send_p('#convos', '/mode +k secret')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {from => 'localhost', mode => '+k', mode_changed => 1, target => '#convos'},
  'mode +k response - current channel'
);

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost MODE #otherchan +k :secret\r\n");
$res = $connection->send_p('', '/mode #otherchan +k secret')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {from => 'localhost', mode => '+k', mode_changed => 1, target => '#otherchan'},
  'mode +k response - with no conversation_id'
);

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost MODE #otherchan -k+m-i+sp\r\n");
$res = $connection->send_p('#convos', '/mode #otherchan -k+m-i+sp')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {from => 'localhost', mode => '-k+m-i+sp', mode_changed => 1, target => '#otherchan'},
  'mode -k response - with custom channel'
);

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost 324 superman #convos +int\r\n");
$res = $connection->send_p('#convos', '/mode #convos +i')->$wait_success;
$server->processed_ok;
is_deeply($res, {mode => '+int', target => '#convos'}, 'mode #convos +i');

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(":localhost 324 superman #convos +nt\r\n");
$res = $connection->send_p('#convos', '/mode #convos -i')->$wait_success;
$server->processed_ok;
is_deeply($res, {mode => '+nt', target => '#convos'}, 'mode +k response - with custom channel');

$server->server_event_ok('_irc_event_mode')
  ->server_write_ok(
  ":localhost 367 superman #convos x!*@* superman!~superman@125-12-219-233.rev.home.ne.jp 1577498687\r\n"
)->server_write_ok(":localhost 368 superman #convos :End of Channel Ban List\r\n");
$res = $connection->send_p('#convos', '/mode b')->$wait_success;
$server->processed_ok;
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
$server->server_event_ok('_irc_event_names')->server_write_ok(['names.irc']);
$res = $connection->send_p('#convos', '/names')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {
    conversation_id => '#convos',
    participants    => [
      {nick => 'superwoman', mode => ''},
      {nick => 'superman',   mode => 'q'},
      {nick => 'robin',      mode => 'a'},
      {nick => 'batboy',     mode => 'h'},
      {nick => 'superboy',   mode => 'o'},
      {nick => 'robyn',      mode => 'v'},
    ],
  },
  'names response',
);

note 'topic';
@state = ();
$server->server_event_ok('_irc_event_topic')
  ->server_write_ok(":localhost 331 superman #convos :No topic is set\r\n");
$res = $connection->send_p('#convos', '/topic')->$wait_success;
$server->processed_ok;
is_deeply($res, {conversation_id => '#convos', topic => ''}, 'topic');

$server->server_event_ok('_irc_event_topic')
  ->server_write_ok(":localhost 332 superman #convos :cool topic\r\n");
$res = $connection->send_p('#convos', '/topic')->$wait_success;
$server->processed_ok;
is_deeply($res, {conversation_id => '#convos', topic => 'cool topic'}, 'topic');

$server->server_event_ok('_irc_event_topic')
  ->server_write_ok(":localhost TOPIC #convos :Some cool\r\n");
$res = $connection->send_p('#convos', '/topic Some cool stuff')->$wait_success;
$server->processed_ok;
is_deeply($res, {conversation_id => '#convos', topic => 'Some cool'}, 'set topic');

cmp_deeply(
  \@state,
  [
    [frozen => superhashof({name => '#convos', topic => 'cool topic'})],
    [frozen => superhashof({name => '#convos', topic => 'Some cool'})],
  ],
  'topic events'
) or diag explain \@state;

note 'ison';
$server->server_event_ok('_irc_event_ison')
  ->server_write_ok(":localhost 303 test21362 :other SuperBoy superbad\r\n");
$res
  = Mojo::Promise->all(map { $connection->send_p('', "/ison $_") } qw(SuperBoy superwoman SUPERBAD))
  ->then(sub { [map { $_->[0] } @_] })->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  [
    {nick => 'SuperBoy',   online => true},
    {nick => 'superwoman', online => false},
    {nick => 'SUPERBAD',   online => true},
  ],
  'ison nick',
);

$server->server_event_ok('_irc_event_ison')
  ->server_write_ok(":localhost 303 test21362 :superduper\r\n");
$res = $connection->send_p('Superduper', '/ison')->$wait_success;
$server->processed_ok;
is_deeply $res, {nick => 'Superduper', online => true}, 'ison';

note 'join';
is $connection->n_conversations, 2, 'number of conversations before list join';
$connection->send_p('', '/join #foo,#bar,#baz')->$wait_success;
is $connection->n_conversations, 2, 'number of conversations did not change';

note 'join redirected';
$server->server_event_ok('_irc_event_join')->server_write_ok(['join-redirected-1.irc'])
  ->server_event_ok('_irc_event_join')->server_write_ok(['join-redirected-2.irc']);
$res = $connection->send_p('', '/join #redirected')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {conversation_id => '##redirected', topic => '', topic_by => '', users => {}},
  'join redirected'
);

note 'join protected';
$server->server_event_ok('_irc_event_join')->server_write_ok(['join-protected.irc']);
$res = $connection->send_p('', '/join #protected S3cret')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {conversation_id => '#protected', topic => '', topic_by => '', users => {}},
  'join protected'
);

note 'join invite only';
ok !$connection->get_conversation('#invite_only'), 'invite_only is not joined';
$server->server_event_ok('_irc_event_join')->server_write_ok(['join-invite-only.irc']);
$res = $connection->send_p('', '/join #invite_only')->$wait_reject('Cannot join channel (+i)');
$server->processed_ok;
my $invite_only = $connection->get_conversation('#invite_only');
is $invite_only->frozen, 'This channel requires an invitation.', 'invite_only frozen';

$res = $connection->send_p('', '/join some_user')->$wait_success;
is $res->{conversation_id}, 'some_user', 'join alias for query';
$connection->send_p('', '/part some_user')->$wait_success('clean up for state test later on');

note 'invite';
$server->server_event_ok('_irc_event_invite')->server_write_ok(['invitation.irc']);
$res = $connection->send_p('#invite_only', '/invite devman')->$wait_success;
$server->processed_ok;
is_deeply($res, {conversation_id => '#invite_only', invited => 'devman'}, 'invitation sent');

note 'list';
$p = $connection->send_p('', '/list');
$server->server_event_ok('_irc_event_list')
  ->server_write_ok(":localhost 321 superman Channel :Users  Name\r\n")
  ->client_event_ok('_irc_event_rpl_liststart')->process_ok;
$res = $p->$wait_success;
is_deeply($res, {n_conversations => 0, conversations => [], done => false}, 'list empty');

$server->server_write_ok(":localhost 322 superman #Test123 1 :[+nt]\r\n")
  ->client_event_ok('_irc_event_rpl_list')
  ->server_write_ok(":localhost 322 superman #convos 42 :[+nt] some cool topic\r\n")
  ->client_event_ok('_irc_event_rpl_list')->process_ok;
$res = $connection->send_p('', '/list')->$wait_success;
is_deeply(
  $res,
  {
    done            => false,
    n_conversations => 2,
    conversations   => [
      {conversation_id => '#convos',  name => '#convos', n_users => 42, topic => 'some cool topic'},
      {conversation_id => '#test123', name => '#Test123', n_users => 1, topic => ''},
    ],
  },
  'list conversations',
);

$server->server_write_ok(":localhost 323 superman :End of /LIST\r\n")
  ->client_event_ok('_irc_event_rpl_listend')->process_ok;
$res = $connection->send_p('', '/list')->$wait_success;
ok $res->{done}, 'list done';

note 'whois';
$server->server_event_ok('_irc_event_whois')->server_write_ok(['whois-superwoman.irc']);
$res = $connection->send_p('', '/whois superwoman ')->$wait_success;
$server->processed_ok;
is_deeply(
  $res,
  {
    away        => false,
    channels    => {'#test123' => {mode => ''}, '#convos' => {mode => 'o'}},
    fingerprint => '27c8d553c199533e882a99659a8f942220281ec6',
    host        => 'irc.example.com',
    idle_for    => 17454,
    name        => 'Convos v10.01',
    nick        => 'superwoman',
    secure      => true,
    server      => 'localhost',
    server_info => 'ircd-hybrid 8.1-debian',
    user        => 'SuperWoman',
  },
  'whois'
);

note 'close and part';
$res = $connection->send_p('#convos', '/close superwoman')->$wait_success;
is_deeply($res, {}, 'close superwoman response');

$server->server_event_ok('_irc_event_part')
  ->server_write_ok(":localhost 442 superman #foo :You are not on that channel\r\n");
$connection->send_p('#convos', '/close #foo')->catch(sub { $err = shift })->$wait_success;
is $err, 'You are not on that channel', 'close #foo';

$connection->conversation({name => '#convos'});
ok $connection->get_conversation('#convos'), 'has convos conversation';
$server->server_event_ok('_irc_event_part')->server_write_ok(":localhost PART #convos\r\n");
$res = $connection->send_p('#convos', '/part')->$wait_success;
$server->processed_ok;
is_deeply($res, {}, 'part #convos');
ok !$connection->get_conversation('#convos'), 'convos conversation was removed';

note 'unknown commands';
$connection->send_p('', '/foo')->catch(sub { $err = shift })->$wait_success;
like $err, qr{Unknown command}, 'Unknown command';

$server->server_event_ok('_irc_event_foo')
  ->server_write_ok(":localhost 421 superman FOO :Unknown command\r\n")
  ->client_event_ok('_irc_event_err_unknowncommand');
$connection->send_p('', '/quote FOO some stuff')->$wait_success;
$server->process_ok;

note 'oper command';
$server->server_event_ok('_irc_event_oper')->server_write_ok(['oper.irc']);
$res = $connection->send_p('', '/oper foo bar')->catch(sub { $err = shift })->$wait_success;
$server->processed_ok;
is $res->{server_op}, true, 'server_op';

note 'server disconnect';
@state = ();
my $id = $connection->{stream_id};
ok !!Mojo::IOLoop->stream($id), 'got stream';
$connection->once(state => sub { Mojo::IOLoop->stop });
$server->close_connections;
Mojo::IOLoop->start;
ok !Mojo::IOLoop->stream($id), 'stream was removed';

$server->server_event_ok('_irc_event_nick')->server_write_ok(['welcome.irc'])
  ->client_event_ok('_irc_event_rpl_welcome')->process_ok;
isnt $connection->{stream_id}, $id, 'got new stream id';
ok !!Mojo::IOLoop->stream($connection->{stream_id}), 'got new stream';

cmp_deeply(
  \@state,
  [
    [connection => superhashof({state           => 'queued'})],
    [frozen     => superhashof({conversation_id => '##redirected'})],
    [frozen     => superhashof({conversation_id => '#protected'})],
    [connection => superhashof({state           => 'connected'})],
    [me         => superhashof({nick            => 'superman'})],
    [frozen     => superhashof({conversation_id => '##redirected'})],
  ],
  'connection states'
) or diag explain \@state;

note 'reconnect';
Mojo::Promise->timer(0.4)->wait;
$connection->send_p('', '/reconnect')->$wait_success('reconnect command');

done_testing;

__DATA__
@@ join-invite-only.irc
:localhost 473 superman #invite_only :Cannot join channel (+i)
@@ join-protected.irc
:localhost 366 superman #protected :End of /NAMES list.
@@ join-redirected-1.irc
:localhost 470 superman #redirected ##redirected :Forwarding to another channel
@@ join-redirected-2.irc
:localhost 332 superman ##redirected :Used to be #redirected
:localhost 353 superman @ ##redirected :superwoman @superman
:localhost 366 superman ##redirected :End of /NAMES list.
@@ invitation.irc
:localhost 341 superman devman #invite_only
@@ names.irc
:localhost 353 superman = #convos :superwoman ~superman &robin
:localhost 353 superman = #convos :%batboy @superboy +robyn
:localhost 366 superman #convos :End of /NAMES list.
@@ oper.irc
:localhost 381 superman :You are now an IRC operator
@@ whois-superwoman.irc
:localhost 311 superman superwoman SuperWoman irc.example.com * :Convos v10.01
:localhost 319 superman superwoman :#test123 @#convos
:localhost 312 superman superwoman localhost :ircd-hybrid 8.1-debian
:localhost 671 superman superwoman :is using a secure connection
:localhost 276 superman superwoman :has client certificate fingerprint 27c8d553c199533e882a99659a8f942220281ec6
:localhost 378 superman superwoman :is connecting from *@125-12-222-122.rev.home.ne.jp 125.12.222.122
:localhost 338 superman superwoman 255.255.255.255 :actually using host
:localhost 317 superman superwoman 17454 1432930742 :seconds idle, signon time
:localhost 318 superman superwoman :End of /WHOIS list.
