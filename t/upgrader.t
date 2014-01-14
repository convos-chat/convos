use t::Helper qw( no_web );
use Convos::Upgrader;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

my $upgrader = Convos::Upgrader->new;
my ($finish, $err);

{    # v0_3002
  redis_do(del => 'convos:version', 'irc:networks');
  redis_do(del => map {"irc:network:$_"} qw( efnet freenode magnet ));
  redis_do(set => 'convos:version', $ENV{CONVOS_VERSION}) if $ENV{CONVOS_VERSION};
}

{    # v0_3004
  redis_do(sadd => 'users', 'jhthorsen');
  redis_do(hset => 'user:jhthorsen', 'email', 'jhthorsen@cpan.org');
  redis_do(
    zadd => 'user:jhthorsen:conversations',
    1389446375.9990001, 'irc:2eperl:2eorg:00:23convos', 1389446374.9990001, 'convos:2eby:00marcus'
  );
  redis_do(sadd => 'connections', 'jhthorsen:irc.perl.org', 'jhthorsen:convos.by');
  redis_do(sadd => 'user:jhthorsen:connections', 'irc.perl.org', 'convos.by');
  redis_do(hset => 'user:jhthorsen:connection:irc.perl.org', server => 'irc.perl.org');
  redis_do(hset => 'user:jhthorsen:connection:convos.by',    server => 'convos.by');
  redis_do(
    'zadd',
    'user:jhthorsen:connection:irc.perl.org:#convos:msg',
    1389446275.9390020,
    "{\"nick\":\"batman\",\"event\":\"message\",\"uuid\":\"b3faa8a4-61e0-dd87-c29e-b469c5fddde2\",\"host\":\"ti0034a400-4176.bb.online.no\",\"message\":\"yay\",\"target\":\"#convos\",\"timestamp\":1389446385.81372,\"user\":\"jhthorsen\",\"server\":\"irc.perl.org\",\"highlight\":0}",
  );
  redis_do(
    'zadd',
    'user:jhthorsen:connection:convos.by:marcus:msg',
    1389446123.2134020,
    "{\"nick\":\"batman\",\"event\":\"message\",\"uuid\":\"b3faa8a4-61e0-dd87-c29e-b469c5fddde2\",\"host\":\"ti0034a400-4176.bb.online.no\",\"message\":\"yay\",\"target\":\"#convos\",\"timestamp\":1389446385.81372,\"user\":\"jhthorsen\",\"server\":\"irc.perl.org\",\"highlight\":0}",
  );
}

{
  $upgrader->redis(Mojo::Redis->new(server => $ENV{REDIS_TEST_DATABASE}));
  $upgrader->on(error  => sub { $err    = pop; Mojo::IOLoop->stop; });
  $upgrader->on(finish => sub { $finish = 1;   Mojo::IOLoop->stop; });
  $upgrader->run;
  Mojo::IOLoop->start;

  is $finish, 1,     'finishd';
  is $err,    undef, 'no error';
  is redis_do(get => 'convos:version'), '0.3004', 'convos:version is set';
}

{    # v0_3002
  is_deeply([sort @{redis_do(smembers => 'irc:networks') || []}], [qw( efnet freenode magnet )], 'irc:networks added',);
  is_deeply(
    redis_do(hgetall => 'irc:network:magnet'),
    {home_page => "http://www.irc.perl.org", channels => '#convos', server => "irc.perl.org", port => 7062, tls => 1,},
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
    [sort @{redis_do(smembers => 'connections') || []}],
    ['jhthorsen:convos-by', 'jhthorsen:magnet',],
    'converted connection keys',
  );

  is_deeply(
    redis_do(hgetall => 'user:jhthorsen'),
    {email => 'jhthorsen@cpan.org', avatar => 'jhthorsen@cpan.org',},
    'set avatar email to user email',
  );
}

done_testing;
