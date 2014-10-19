BEGIN { $ENV{TEST_IS_CHANNEL} = 1; }
use t::Helper;

my $time = time;
my @conversations = map { ($time--, $_) } (
  'magnet:00batman',                                                            # valid nick
  'magnet:00foo:60:5b:7bweird:7d:5d',                                           # valid nick
  'magnet:00:23convos',                                                         # valid channel
  'bitlbee:00:26bitlbee',                                                       # valid channel
  'magnet:00x',                                                                 # too short nick
  'magnet:00too_long_nick1234567890',                                           # too long nick
  'magnet:0012345',                                                             # nick cannot start with a number
  'magnet:00:23too_12345678901234567890123456789012345678901234567890_long',    # too long channel
  'magnet:00:03super_invalid',                                                  # invalid start character
);

redis_do(
  [hmset => 'user:doe',               digest => 'E2G3goEIb8gpw', email => ''],
  [zadd  => 'user:doe:conversations', @conversations],
  [sadd => 'user:doe:connections', 'magnet', 'bitlbee'],
  [hmset => 'user:doe:connection:magnet',  nick => 'doe', state => 'disconnected'],
  [hmset => 'user:doe:connection:bitlbee', nick => 'doe', state => 'disconnected'],
);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
$t->get_ok('/magnet/batman')->status_is(200)->header_is('X-Is-Channel', 0);
$t->get_ok('/magnet/foo`[{weird}]')->status_is(200)->header_is('X-Is-Channel', 0);
$t->get_ok('/magnet/%23convos')->status_is(200)->header_is('X-Is-Channel', 1);
$t->get_ok('/bitlbee/&bitlbee')->status_is(200)->header_is('X-Is-Channel', 1);
$t->get_ok('/invalid/x')->status_is(404)->header_is('X-Is-Channel', undef);
$t->get_ok('/invalid/too_long_nick1234567890')->status_is(404)->header_is('X-Is-Channel', undef);
$t->get_ok('/invalid/12345')->status_is(404)->header_is('X-Is-Channel', undef);
$t->get_ok('/invalid/%23too_12345678901234567890123456789012345678901234567890_long')->status_is(404)
  ->header_is('X-Is-Channel', undef);
$t->get_ok('/invalid/%03super_invalid')->status_is(404)->header_is('X-Is-Channel', undef);

done_testing;
