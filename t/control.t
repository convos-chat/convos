use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:doe:conversations', time, 'irc:2eperl:2eorg:00:23convos' ],
  [ sadd => 'user:doe:connections', 'irc.perl.org' ],
  [ hmset => 'user:doe:connection:irc.perl.org', nick => 'doe' ],
  [ del => 'core:control' ],
);

$t->get_ok('/irc.perl.org/control/start.json')->status_is(403);
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);

$t->get_ok('/irc.perl.org/control/invalid.json')->status_is(302); # TODO: This status does not make much sense
$t->get_ok('/irc.perl.org/control/start.json')->status_is(200);
$t->get_ok('/irc.perl.org/control/stop.json')->status_is(200);
$t->get_ok('/irc.perl.org/control/restart.json')->status_is(200);

is_deeply(
  redis_do(lrange => 'core:control', 0, -1),
  [qw(
    restart:doe:irc.perl.org
    stop:doe:irc.perl.org
    start:doe:irc.perl.org
  )],
  'commands pushed to queue',
);

done_testing;
