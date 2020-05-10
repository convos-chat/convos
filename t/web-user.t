#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{CONVOS_DEFAULT_CONNECTION} ||= 'irc://localhost:6123/%23convos';
$ENV{CONVOS_OPEN_TO_PUBLIC} = 1;

$ENV{CONVOS_STUN}
  = 'stun://superwoman:kryptonite@stun.example.com:3478?&bundlePolicy=balanced&credentialType=password&iceTransportPolicy=all&rtcpMuxPolicy=require';
$ENV{CONVOS_TURN} = 'turn://superman:k2@turn.example.com:3478';

my $t = t::Helper->t;

$t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->delete_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->post_ok('/api/user', json => {})->status_is(401)
  ->json_is('/errors/0/message', 'Need to log in first.')->json_is('/errors/0/path', '/');

$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com  ', password => '  longenough '})->status_is(200)
  ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
my $registered = $t->tx->res->json->{registered};

$t->post_ok('/api/user', json => {})->status_is(200);

$t->get_ok('/api/user')->status_is(200);
is_deeply(
  $t->tx->res->json,
  {
    email              => 'superman@example.com',
    highlight_keywords => [],
    registered         => $registered,
    roles              => ['admin'],
    uid                => 1,
    unread             => 0,
    rtc                => {
      bundlePolicy       => 'balanced',
      iceTransportPolicy => 'all',
      rtcpMuxPolicy      => 'require',
      ice_servers        => [
        {
          credential      => 'kryptonite',
          credential_type => 'password',
          urls            => 'stun:stun.example.com:3478',
          username        => 'superwoman',
        },
        {
          credential      => 'k2',
          credential_type => 'password',
          urls            => 'turn:turn.example.com:3478',
          username        => 'superman',
        },
      ],
    },
  },
  'user object'
);

$t->post_ok('/api/user', json => {highlight_keywords => [' ', '-', '.', '  ,', '    ', 'foo ']})
  ->status_is(200);
$t->get_ok('/api/user')->status_is(200)->json_is('/email', 'superman@example.com')
  ->json_is('/highlight_keywords', ['foo']);

my $user = $t->app->core->get_user('superman@example.com');
$user->unread(4);

my $last_active = Mojo::Date->new(1471623050)->to_datetime;
my $last_read   = Mojo::Date->new(1471623058)->to_datetime;
$user->connection({name => 'localhost', protocol => 'irc'})->dialog({name => '#convos'})
  ->last_read($last_read)->last_active($last_active);
$t->get_ok('/api/user?connections=true&dialogs=true')->status_is(200)
  ->json_is('/email', 'superman@example.com')->json_is(
  '/connections',
  [{
    connection_id       => 'irc-localhost',
    me                  => {nick => 'superman'},
    name                => 'localhost',
    on_connect_commands => [],
    protocol            => 'irc',
    state               => 'disconnected',
    url                 => 'irc://localhost:6123/%23convos?nick=superman&tls=1',
    wanted_state        => 'connected',
  }]
)->json_is(
  '/dialogs',
  [{
    connection_id => 'irc-localhost',
    dialog_id     => '#convos',
    frozen        => 'Not connected.',
    last_active   => '2016-08-19T16:10:50Z',
    last_read     => '2016-08-19T16:10:58Z',
    name          => '#convos',
    topic         => '',
    unread        => 0,
  }]
);

$t->post_ok('/api/notifications/read')->status_is(200);

$t->delete_ok('/api/user')->status_is(400)
  ->json_is('/errors/0/message', 'You are the only user left.');

$t->get_ok('/api/user/logout')->status_is(200);
$t->get_ok('/api/user')->status_is(401);

done_testing;
