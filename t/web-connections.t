#!perl
use lib '.';
use t::Helper;

local $TODO = $ENV{TRAVIS_BUILD_ID} && 'Fails on travis for some unknown reason';

$ENV{CONVOS_CONNECT_DELAY}   = 0.1;
$ENV{CONVOS_CONNECT_TIMEOUT} = 0.1;
$ENV{CONVOS_BACKEND}         = 'Convos::Core::Backend';
my $t = t::Helper->t;
$t->app->log->level('fatal');

my $port = $t->ua->server->nb_url->port;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
my $connection;

subtest 'initial' => sub {
  $t->get_ok('/api/connections')->status_is(401);
  $t->post_ok('/api/connections', json => {url   => "irc://localhost:$port"})->status_is(401);
  $t->post_ok('/api/user/login',  json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
  $t->get_ok('/api/connections')->status_is(200)->json_is('/connections', []);
};

subtest 'create connections' => sub {
  $t->post_ok('/api/connections',
    json => {url => "irc://localhost:$port", wanted_state => 'disconnected'})->status_is(200);
  $t->post_ok('/api/connections',
    json => {url => 'irc://irc.example.com:6667', wanted_state => 'disconnected'})->status_is(200);
  $t->post_ok('/api/connections', json => {url => 'irc://irc.example.com:6667'})->status_is(400)
    ->json_is('/errors/0/message', 'Connection already exists.');
  $t->post_ok('/api/connections', json => {url => 'foo://example.com'})->status_is(400)
    ->json_is('/errors/0/message', 'Convos::Core::Connection::Foo is not supported.');
};

subtest 'get connections' => sub {
  $t->get_ok('/api/connections')->status_is(200)->json_is(
    '/connections/0',
    {
      connection_id       => 'irc-example',
      name                => 'example',
      info                => {authenticated => false, capabilities => {}},
      on_connect_commands => [],
      service_accounts    => [qw(chanserv nickserv)],
      state               => 'disconnected',
      url                 => 'irc://irc.example.com:6667',
      wanted_state        => 'disconnected',
    }
  )->json_is('/connections/1/connection_id', 'irc-localhost')
    ->json_is('/connections/1/name',         'localhost')
    ->json_is('/connections/1/wanted_state', 'disconnected')
    ->json_is('/connections/1/url',          "irc://localhost:$port");
};

subtest 'update connections' => sub {
  $t->post_ok('/api/connection/irc-doesnotexist', json => {url => 'foo://example.com:9999'})
    ->status_is(404);
  $t->post_ok('/api/connection/irc-example', json => {})->status_is(200);
};

subtest 'update on_connect_commands' => sub {
  $connection = $user->get_connection('irc-localhost');
  $connection->reconnect_delay(100);
  $t->post_ok('/api/connection/irc-localhost',
    json => {on_connect_commands => [' /msg NickServ identify s3cret   ', '/msg too_cool 123']})
    ->status_is(200)->json_is('/name' => 'localhost')
    ->json_is('/on_connect_commands', ['/msg NickServ identify s3cret', '/msg too_cool 123']);
  is $connection->reconnect_delay, 0, 'reconnect_delay got reset';

  $t->get_ok('/api/connections')->status_is(200)->json_is('/connections/1/on_connect_commands',
    ['/msg NickServ identify s3cret', '/msg too_cool 123']);
};

subtest 'set wanted_state=connected' => sub {
  $t->post_ok('/api/connection/irc-localhost',
    json => {url => 'irc://example.com:9999', wanted_state => 'connected'})->status_is(424)
    ->json_is('/errors/0/path' => '/wanted_state');
};

subtest 'update connection url' => sub {
  $t->post_ok('/api/connection/irc-localhost',
    json => {url => 'irc://foo:bar@example.com:9999?tls=0&nick=superman'})->status_is(424)
    ->json_is('/errors/0/path' => '/wanted_state');
};

subtest 'update connection username and password' => sub {
  $connection->state(connected => '');
  $t->post_ok('/api/connection/irc-localhost',
    json =>
      {url => 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman', wanted_state => 'connected'})
    ->status_is(424)->json_is('/errors/0/path' => '/wanted_state');

  is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman',
    'to json url';

  $t->post_ok('/api/connection/irc-localhost',
    json => {url => 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman'})->status_is(200);
  is $connection->TO_JSON(1)->{url}, 'irc://foo:s3cret@example.com:9999?tls=0&nick=superman',
    'no change with same username';
};

subtest 'remove connections' => sub {
  $t->delete_ok('/api/connection/irc-doesnotexist')->status_is(200);
  $t->delete_ok('/api/connection/irc-localhost')->status_is(200);
};

subtest 'test that "conversation_id" will create a connection and conversation' => sub {
  $t->get_ok('/api/conversations')->status_is(200)->json_is('/conversations', []);
  $t->post_ok('/api/connections',
    json =>
      {conversation_id => '#convos', url => "irc://localhost", wanted_state => 'disconnected'})
    ->status_is(200);
  $t->get_ok('/api/conversations')->status_is(200)
    ->json_is('/conversations/0/conversation_id', '#convos');
};

done_testing;
