use t::Helper;

my $t = t::Helper->t;

$t->websocket_ok('/events/bi-directional');
$t->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

my $port = $t->ua->server->nb_url->port;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->post_ok('/api/connections', json => {state => 'connect', url => "irc://localhost:$port"})
  ->status_is(200);

$t->websocket_ok('/events/bi-directional');

# change from "connecting" got "disconnected"
$user->get_connection('irc-localhost')->state('disconnected');
$t->message_ok->json_message_is('/type', 'state')->json_message_is('/object/name', 'localhost')
  ->json_message_is('/object/state', 'connecting')->json_message_is('/data/0', 'disconnected');

# update profile
$t->send_ok(
  {json => {id => 42, op => 'updateUser', params => {body => {password => 'supersecret'}}}});

# need to skip connection events
while (1) {
  $t->message_ok;
  $t->message->[1] =~ /"registered"/ or next;
  $t->json_message_is('/id', 42)->json_message_is('/body/email', 'superman@example.com');
  last;
}

# Test to make sure we don't leak events.
# The get_ok() is just a hack to make sure the server has
# emitted the "finish" event.
ok $user->has_subscribers($_), "subscribe $_" for $user->EVENTS;
$t->finish_ok;
$t->get_ok('/')->status_is(200);
ok !$user->has_subscribers($_), "unsubscribe $_" for $user->EVENTS;

done_testing;
