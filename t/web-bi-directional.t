BEGIN { $ENV{CONVOS_CONNECT_TIMER} = 0.1 }
use t::Helper;

my $t = t::Helper->t;

$t->websocket_ok('/events/bi-directional');
$t->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret')->save;
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->post_ok('/api/connections', json => {state => 'connect', url => 'irc://localhost:3123'})->status_is(200);

$t->websocket_ok('/events/bi-directional');

# change from "connecting" got "disconnected"
$user->connection('irc-localhost')->state('disconnected');
$t->message_ok->json_message_is('/event', 'state')->json_message_is('/object/name', 'localhost')
  ->json_message_is('/object/state', 'connecting')->json_message_is('/data/0', 'disconnected');

# Test to make sure we don't leak events.
# The get_ok() is just a hack to make sure the server has
# emitted the "finish" event.
ok $user->has_subscribers($_), "subscribe $_" for $user->EVENTS;
$t->finish_ok;
$t->get_ok('/')->status_is(200);
ok !$user->has_subscribers($_), "unsubscribe $_" for $user->EVENTS;

done_testing;
