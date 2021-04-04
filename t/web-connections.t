#!perl
use lib '.';
use t::Helper;

local $TODO = $ENV{TRAVIS_BUILD_ID} && 'Fails on travis for some unknown reason';

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

my $port = $t->ua->server->nb_url->port;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->get_ok('/api/connections')->status_is(401);
$t->post_ok('/api/connections', json => {url => "irc://localhost:$port"})->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/connections')->status_is(200)->json_is('/connections', []);
$t->post_ok('/api/connections',
  json => {url => "irc://localhost:$port", wanted_state => 'disconnected'})->status_is(200);
$t->post_ok('/api/connections',
  json => {url => 'irc://irc.example.com:6667', wanted_state => 'disconnected'})->status_is(200);

$t->post_ok('/api/connections', json => {url => 'irc://irc.example.com:6667'})->status_is(400)
  ->json_is('/errors/0/message', 'Connection already exists.');

$t->post_ok('/api/connections', json => {url => 'foo://example.com'})->status_is(400)
  ->json_is('/errors/0/message', 'Protocol "foo" is not supported.');

$t->get_ok('/api/connections')->status_is(200)->json_is(
  '/connections/0',
  {
    connection_id       => 'irc-example',
    name                => 'example',
    me                  => {authenticated => false, capabilities => {}},
    on_connect_commands => [],
    protocol            => 'irc',
    service_accounts    => [qw(chanserv nickserv)],
    state               => 'disconnected',
    url                 => 'irc://irc.example.com:6667',
    wanted_state        => 'disconnected',
  }
)->json_is('/connections/1/connection_id', 'irc-localhost')
  ->json_is('/connections/1/name',         'localhost')
  ->json_is('/connections/1/wanted_state', 'disconnected')
  ->json_is('/connections/1/url',          "irc://localhost:$port");

$t->post_ok('/api/connection/irc-doesnotexist', json => {url => 'foo://example.com:9999'})
  ->status_is(404);
$t->post_ok('/api/connection/irc-example', json => {})->status_is(200);

my $connection = $user->get_connection('irc-localhost');
$t->post_ok('/api/connection/irc-localhost', json => {url => "irc://localhost:$port"})
  ->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'disconnected');
$t->post_ok('/api/connection/irc-localhost', json => {url => 'irc://example.com:9999'})
  ->status_is(200)->json_is('/name' => 'localhost')
  ->json_like('/url' => qr{irc://example\.com:9999});

$connection->state(disconnected => '');
$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://example.com:9999', wanted_state => 'connected'})->status_is(200)
  ->json_is('/name' => 'localhost')->json_is('/state' => 'queued')
  ->json_is('/url'  => 'irc://example.com:9999?nick=superman&tls=1');

$connection->state(connected => '');
$t->post_ok(
  '/api/connection/irc-localhost',
  json => {
    on_connect_commands => [' /msg NickServ identify s3cret   ', '/msg too_cool 123'],
    wanted_state        => 'connected'
  }
)->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'connected')
  ->json_is('/on_connect_commands', ['/msg NickServ identify s3cret', '/msg too_cool 123'])
  ->json_is('/url' => 'irc://example.com:9999?tls=1&nick=superman');

$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://foo:bar@example.com:9999?tls=0&nick=superman'})->status_is(200)
  ->json_is('/url'   => 'irc://foo:bar@example.com:9999?tls=0&nick=superman')
  ->json_is('/state' => 'queued');

$connection->state(connected => '');
$t->post_ok('/api/connection/irc-localhost',
  json =>
    {url => 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman', wanted_state => 'connected'})
  ->status_is(200)->json_is('/url' => 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman')
  ->json_is('/state' => 'queued');

is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman',
  'to json url';

$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman'})->status_is(200);
is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman',
  'no change with same username';

$t->get_ok('/api/connections')->status_is(200)->json_is('/connections/1/on_connect_commands',
  ['/msg NickServ identify s3cret', '/msg too_cool 123']);

$t->delete_ok('/api/connection/irc-doesnotexist')->status_is(200);
$t->delete_ok('/api/connection/irc-localhost')->status_is(200);

note 'test that "conversation_id" will create a connection and conversation';
$t->get_ok('/api/conversations')->status_is(200)->json_is('/conversations', []);
$t->post_ok('/api/connections',
  json => {conversation_id => '#convos', url => "irc://localhost", wanted_state => 'disconnected'})
  ->status_is(200);
$t->get_ok('/api/conversations')->status_is(200)
  ->json_is('/conversations/0/conversation_id', '#convos');

done_testing;
