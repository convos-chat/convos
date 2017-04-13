use lib '.';
use t::Helper;
use Test::Mojo::IRC;

$ENV{CONVOS_ROOMS_REPLY_DELAY} = 0.1;
$ENV{CONVOS_BACKEND}           = 'Convos::Core::Backend';

my $th   = t::Helper->t;
my $ws   = t::Helper->t($th->app);
my $user = $th->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

for my $t ($th, $ws) {
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
}

$ws->websocket_ok('/events');

$th->get_ok('/api/connection/irc-localhost/rooms')->status_is(404)
  ->json_is('/errors/0/message', 'Connection not found.');

$th->post_ok('/api/connections', json => {url => 'irc://localhost:3123'})->status_is(200);
$th->get_ok('/api/connection/irc-localhost/rooms')->status_is(500)
  ->json_like('/errors/0/message' => qr{not connected}i);

my $irc = Test::Mojo::IRC->start_server;
my $c   = $user->get_connection('irc-localhost');
$th->post_ok('/api/connection/irc-localhost',
  json => {wanted_state => 'connected', url => sprintf('irc://%s?tls=0', $irc->server)})
  ->status_is(200);

for (1 .. 100) {
  $ws->message_ok;
  $ws->message->[1] =~ /"connected"/ or next;
  $ws->json_message_is('/connection_id', 'irc-localhost')->json_message_is('/state', 'connected');
  last;
}

$th->get_ok('/api/connection/irc-localhost/rooms')->status_is(200)->json_is('/end' => false)
  ->json_is('/n_rooms' => 0)->json_is('/rooms', []);

$irc->run(
  [qr{LIST}, ['list.irc']],
  sub {
    delete $_->{ts} for values %{$c->_room_cache};    # force LIST to be sent again
    $th->get_ok('/api/connection/irc-localhost/rooms')->status_is(200)->json_is('/end' => true)
      ->json_is('/n_rooms' => 6)->json_is('/rooms/0/name', '#demo')
      ->json_is('/rooms/0/n_users', 19)->json_is('/rooms/0/topic', 'demozone');
  }
);

$th->get_ok('/api/connection/irc-localhost/rooms')->status_is(200)->json_is('/n_rooms' => 6);

$th->get_ok('/api/connection/irc-localhost/rooms?match=o')->status_is(200)->json_is('/end' => true)
  ->json_is('/n_rooms' => 3)->json_is('/rooms/0/name', '#convos')
  ->json_is('/rooms/1/name', '#demo')->json_is('/rooms/2/name', '#root')
  ->json_is('/rooms/3', undef);

$th->get_ok('/api/connection/irc-localhost/rooms?match=skillz')->status_is(200)
  ->json_is('/n_rooms' => 1)->json_is('/rooms/0/name', '#test');

done_testing;

__DATA__
@@ list.irc
:hybrid8.debian.local 321 superman Channel :Users  Name
:hybrid8.debian.local 322 superman #pwd 1 :
:hybrid8.debian.local 322 superman #demo 19 :demozone
:hybrid8.debian.local 322 superman #highstreet 1 :
:hybrid8.debian.local 322 superman #test 12 :Test skillz
:hybrid8.debian.local 322 superman #convos 8 :Convos channel
:hybrid8.debian.local 322 superman #root 1 :
:hybrid8.debian.local 323 superman :End of /LIST
