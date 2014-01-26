BEGIN {
  $ENV{CONVOS_SKIP_VERSION_CHECK} = 1;    # skip automatic upgrade on clean database
}
use t::Helper;
use Convos::Upgrader;

# Example usage for running on live database:
# SAVE_NEW_STATE=1 BOOT_DATABASE= prove -vl t/upgrader.t
# Requirements:
# * Input database: local/dump.rdb
# * Redis server port: 30000

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

my $upgrader = $t->app->upgrader;
my ($finish, $err, @data);

unless ($ENV{BOOT_DATABASE}) {

  # v0_3002
  redis_do(set => 'convos:version', $ENV{CONVOS_VERSION}) if $ENV{CONVOS_VERSION};

  # v0_3004
  redis_do(hset => 'user:jhthorsen', 'email', 'jhthorsen@cpan.org');
  redis_do(
    zadd => 'user:jhthorsen:conversations',
    1389446375.9990001, 'irc:2eperl:2eorg:00:23convos', 1389446374.9990001, 'irc:2econvos:2eby:00marcus'
  );
  redis_do(sadd => 'connections', 'jhthorsen:irc.perl.org', 'jhthorsen:irc.convos.by');
  redis_do(sadd => 'user:jhthorsen:connections', 'irc.perl.org', 'irc.convos.by');
  redis_do(hset => 'user:jhthorsen:connection:irc.perl.org',  server => 'irc.perl.org');
  redis_do(hset => 'user:jhthorsen:connection:irc.convos.by', server => 'irc.convos.by');
  redis_do(
    'zadd',
    'user:jhthorsen:connection:irc.perl.org:#convos:msg',
    1389446275.9390020,
    "{\"nick\":\"batman\",\"event\":\"message\",\"uuid\":\"b3faa8a4-61e0-dd87-c29e-b469c5fddde2\",\"host\":\"ti0034a400-4176.bb.online.no\",\"message\":\"yay\",\"target\":\"#convos\",\"timestamp\":1389446385.81372,\"user\":\"jhthorsen\",\"server\":\"irc.perl.org\",\"highlight\":0}",
  );
  redis_do(
    'zadd',
    'user:jhthorsen:connection:irc.convos.by:marcus:msg',
    1389446123.2134020,
    "{\"nick\":\"batman\",\"event\":\"message\",\"uuid\":\"b3faa8a4-61e0-dd87-c29e-b469c5fddde2\",\"host\":\"ti0034a400-4176.bb.online.no\",\"message\":\"yay\",\"target\":\"#convos\",\"timestamp\":1389446385.81372,\"user\":\"jhthorsen\",\"server\":\"irc.perl.org\",\"highlight\":0}",
  );
}

{
  $upgrader->redis(Mojo::Redis->new(server => $ENV{REDIS_TEST_DATABASE}));
  $upgrader->run(sub { $err = pop; $finish = 1; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;

  is $finish, 1,  'finished';
  is $err,    '', 'no error';
  is redis_do(get => 'convos:version'), '0.3005', 'convos:version is set';
}

{    # v0_3002
  is_deeply([sort @{redis_do(smembers => 'irc:networks') || []}], [qw( efnet freenode magnet )], 'irc:networks added',);
  is_deeply(
    redis_do(hgetall => 'irc:network:magnet'),
    {home_page => "http://www.irc.perl.org", channels => '#convos', server => "irc.perl.org", port => 6667, tls => 0,},
    'got network config for magnet',
  );
}

{    # v0_3004
  is_deeply(
    [sort @{redis_do(zrange => 'user:jhthorsen:conversations', 0, -1) || []}],
    ['convos-by:00marcus', 'magnet:00:23convos'],
    'converted conversation names',
  );
  is_deeply(
    [sort @{redis_do(smembers => 'user:jhthorsen:connections') || []}],
    [qw( convos-by magnet )], 'converted connection names',
  );
  is_deeply(
    [sort @{redis_do(keys => 'user:jhthorsen:connection*') || []}],
    [
      'user:jhthorsen:connection:convos-by', 'user:jhthorsen:connection:convos-by:marcus:msg',
      'user:jhthorsen:connection:magnet',    'user:jhthorsen:connection:magnet:#convos:msg',
      'user:jhthorsen:connections',
    ],
    'converted connection keys',
  );
  is_deeply(
    [@data = sort @{redis_do(smembers => 'connections') || []}],
    ['jhthorsen:convos-by', 'jhthorsen:magnet',],
    'converted connections',
  ) or diag join '|', @data;

  is_deeply(
    redis_do(hgetall => 'user:jhthorsen'),
    {email => 'jhthorsen@cpan.org', avatar => 'jhthorsen@cpan.org',},
    'set avatar email to user email',
  );
}

if ($ENV{SAVE_NEW_STATE}) {
  redis_do(qw( config set dbfilename new.rdb ));
  redis_do(qw( save ));
}

done_testing;
