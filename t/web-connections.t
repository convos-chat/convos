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
    url                 => 'irc://irc.example.com:6667?nick=superman'
  }
  )->json_is('/connections/1/connection_id', 'irc-localhost')
  ->json_is('/connections/1/name', 'localhost')
  ->json_is('/connections/1/url',  "irc://localhost:$port?nick=superman&tls=0");

$t->post_ok('/api/connection/irc-doesnotexist', json => {url => 'foo://example.com:9999'})
  ->status_is(404);
$t->post_ok('/api/connection/irc-example', json => {})->status_is(200);
$t->post_ok('/api/connection/irc-localhost', json => {url => 'foo://example.com:9999'})
  ->status_is(200)->json_is('/name' => 'localhost')->json_is('/state' => 'queued')
  ->json_like('/url' => qr{irc://example.com:9999\?nick=superman});

$t->delete_ok('/api/connection/irc-doesnotexist')->status_is(200);
$t->delete_ok('/api/connection/irc-localhost')->status_is(200);

done_testing;
