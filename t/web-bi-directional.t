BEGIN { $ENV{CONVOS_CONNECT_TIMER} = 0.1 }
use t::Helper;

my $t = t::Helper->t;

$t->websocket_ok('/events/bi-directional');
$t->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret')->save;
$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->post_ok('/1.0/connections', json => {state => 'connect', url => 'irc://localhost:3123'})->status_is(200);

$t->websocket_ok('/events/bi-directional');
$t->message_ok->json_message_is('/event', 'log')->json_message_is('/level', 'warn')
  ->json_message_is('/message', 'Connection refused')->json_message_is('/name', 'localhost')
  ->json_message_is('/protocol', 'irc');

done_testing;
