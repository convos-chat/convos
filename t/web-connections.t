#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

my $port = $t->ua->server->nb_url->port;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->get_ok('/api/connections')->status_is(401);
$t->post_ok('/api/connections', json => {url => "irc://localhost:$port"})->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/connections')->status_is(200)->json_is('/connections', []);
$t->post_ok('/api/connections', json => {url => "irc://localhost:$port"})->status_is(200);
$t->post_ok('/api/connections', json => {url => 'irc://irc.example.com:6667'})->status_is(200);

$t->post_ok('/api/connections', json => {url => 'irc://irc.example.com:6667'})->status_is(400)
  ->json_is('/errors/0/message', 'Connection already exists.');

$t->post_ok('/api/connections', json => {url => 'foo://example.com'})->status_is(400)
  ->json_is('/errors/0/message', 'Protocol "foo" is not supported.');

$t->get_ok('/api/connections')->status_is(200)->json_is(
  '/connections/0',
  {
    connection_id       => 'irc-example',
    name                => 'example',
    me                  => {},
    on_connect_commands => [],
    protocol            => 'irc',
    state               => 'disconnected',
    url                 => 'irc://irc.example.com:6667?nick=superman',
    wanted_state        => 'connected',
  }
  )->json_is('/connections/1/connection_id', 'irc-localhost')
  ->json_is('/connections/1/name', 'localhost')
  ->json_is('/connections/1/url',  "irc://localhost:$port?nick=superman&tls=0");

$t->post_ok('/api/connection/irc-doesnotexist', json => {url => 'foo://example.com:9999'})
  ->status_is(404);
$t->post_ok('/api/connection/irc-example', json => {})->status_is(200);

my $connection = $user->get_connection('irc-localhost')->state('connected');
$t->post_ok('/api/connection/irc-localhost', json => {url => "irc://localhost:$port"})
  ->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'connected');
$t->post_ok('/api/connection/irc-localhost', json => {url => 'irc://example.com:9999'})
  ->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'queued')
  ->json_like('/url' => qr{irc://example\.com:9999\?nick=superman});

$connection->state('disconnected');
$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://example.com:9999', wanted_state => 'connected'})->status_is(200)
  ->json_is('/name' => 'localhost')->json_is('/state' => 'queued')
  ->json_is('/url' => 'irc://example.com:9999');

$connection->state('connected');
$t->post_ok(
  '/api/connection/irc-localhost',
  json => {
    on_connect_commands => [' /msg NickServ identify s3cret   ', '/msg too_cool 123'],
    wanted_state        => 'connected'
  }
  )->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'connected')
  ->json_is('/on_connect_commands', ['/msg NickServ identify s3cret', '/msg too_cool 123'])
  ->json_is('/url' => 'irc://example.com:9999');

$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://foo:bar@example.com:9999?nick=superman&tls=0'})->status_is(200)
  ->json_is('/url'   => 'irc://foo:bar@example.com:9999?nick=superman&tls=0')
  ->json_is('/state' => 'queued');

$connection->state('connected');
$t->post_ok('/api/connection/irc-localhost',
  json =>
    {url => 'irc://foo:s3cret@example.com:9999?nick=superman&tls=0', wanted_state => 'connected'})
  ->status_is(200)->json_is('/url' => 'irc://foo:s3cret@example.com:9999?nick=superman&tls=0')
  ->json_is('/state' => 'queued');

is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?nick=superman&tls=0',
  'to json url';

$t->post_ok('/api/connection/irc-localhost',
  json => {url => 'irc://foo:s3cret@example.com:9999?nick=superman&tls=0'})->status_is(200);
is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?nick=superman&tls=0',
  'no change with same username';

$t->get_ok('/api/connections')->status_is(200)->json_is('/connections/1/on_connect_commands',
  ['/msg NickServ identify s3cret', '/msg too_cool 123']);

$t->delete_ok('/api/connection/irc-doesnotexist')->status_is(200);
$t->delete_ok('/api/connection/irc-localhost')->status_is(200);

done_testing;
