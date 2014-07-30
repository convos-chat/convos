use t::Helper;

redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
$t->websocket_ok('/socket')->send_ok('PING')->message_ok->message_is('PONG');
$t->finish_ok;

$ENV{CONVOS_REDIS_URL} = 'redis://localhost:1';
$t->websocket_ok('/socket')->send_ok('PING');
$t->finished_ok(1005, 'server shut down websocket');

done_testing;

