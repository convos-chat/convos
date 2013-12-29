use t::Helper qw( no_web );
use Convos::Upgrader;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $upgrader = Convos::Upgrader->new;
my($finish, $err);

{
  redis_do(del => 'convos:version', 'irc:networks');
  redis_do(del => map { "irc:network:$_" } qw( efnet freenode magnet ));
  redis_do(set => 'convos:version', $ENV{CONVOS_VERSION}) if $ENV{CONVOS_VERSION};
}

{
  $upgrader->redis(Mojo::Redis->new(server => $ENV{REDIS_TEST_DATABASE}));
  $upgrader->on(error => sub { $err = pop; Mojo::IOLoop->stop; });
  $upgrader->on(finish => sub { $finish = 1; Mojo::IOLoop->stop; });
  $upgrader->run;
  Mojo::IOLoop->start;

  is $finish, 1, 'finishd';
  is $err, undef, 'no error';
  is redis_do(get => 'convos:version'), '0.3002', 'convos:version is set';
}

{
  is_deeply(
    [ sort @{ redis_do([smembers => 'irc:networks']) || [] } ],
    [ qw( efnet freenode magnet ) ],
    'irc:networks added',
  );
  is_deeply(
    redis_do([hgetall => 'irc:network:magnet']),
    {
      home_page => "http://www.irc.perl.org",
      server => "irc.perl.org",
      port => 7062,
      tls => 1,
    },
    'got network config for magnet',
  );
}

done_testing;
