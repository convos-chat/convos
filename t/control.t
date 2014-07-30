use t::Helper;

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe', state => ''],
  [del   => 'core:control'],
);

$t->get_ok('/connection/magnet/control/start.json')->status_is(403);
$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);

$t->get_ok('/connection/magnet/control.json?cmd=invalid')->status_is(400);
$t->get_ok('/connection/magnet/control.json?cmd=start')->status_is(400);

$t->post_ok('/connection/magnet/control.json?cmd=start')->status_is(200)->json_is('/state', 'starting');

$t->post_ok('/connection/magnet/control.json?cmd=stop')->status_is(200)->json_is('/state', 'stopping');

$t->post_ok('/connection/magnet/control.json?cmd=restart')->status_is(200)->json_is('/state', 'restarting');

$t->get_ok('/connection/magnet/control.json?cmd=state')->status_is(200)
  ->json_is('/state', 'disconnected', 'default value for state');

{
  redis_do(hset => 'user:doe:connection:magnet', state => 'connected');
  $t->get_ok('/connection/magnet/control.json?cmd=state')->status_is(200)->json_is('/state', 'connected');
  $t->get_ok('/connection/magnet/control?cmd=state')->status_is(200)->content_is("connected\n");
}

is_deeply(
  redis_do(lrange => 'core:control', 0, -1),
  [
    qw(
      restart:doe:magnet
      stop:doe:magnet
      start:doe:magnet
      )
  ],
  'commands pushed to queue',
);

{
  $t->post_ok('/connection/magnet/control?cmd=start')->status_is(302)->header_is(Location => '/magnet');
}

done_testing;
