#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

$t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->get_ok('/login')->status_is(200);
$t->get_ok('/api/user')->status_is(401);

# make sure this url does not exist from web
$t->get_ok('/user/recover/superman@example.com')->status_is(404);

$t->post_ok('/api/user/login')->status_is(400)
  ->json_is('/errors/0', {message => 'Expected object - got null.', path => '/body'});

$t->post_ok('/api/user/login', json => {email => 'xyz', password => 'foo'})->status_is(400)
  ->json_is('/errors/0', {message => 'Does not match email format.', path => '/body/email'});

$t->post_ok('/api/user/login', json => {email => 'superman@example.com'})->status_is(400)
  ->json_is('/errors/0/path', '/body/password');

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 'xyz'})
  ->status_is(400)->json_is('/errors/0', {message => 'Invalid email or password.', path => '/'});

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200)->json_is('/email', 'superman@example.com')
  ->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);

$t->websocket_ok('/events')
  ->send_ok({json => {method => 'load', object => 'user', params => {connections => 1}}})
  ->message_ok->json_message_is('/user/email', 'superman@example.com')
  ->json_message_is('/user/default_connection', 'irc://chat.freenode.net:6697/%23convos')
  ->json_message_is('/user/forced_connection',  false)->finish_ok;

$t->get_ok('/api/user')->status_is(200);
$t->get_ok('/login')->status_is(200);
$t->get_ok('/logout')->status_is(302)->header_is(Location => '/login');
$t->get_ok('/login')->status_is(200);
$t->get_ok('/api/user')->status_is(401);

done_testing;
