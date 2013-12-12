use t::Helper;
use Test::More;
use Convos::Loopback;
use Convos::Core::Connection;

plan skip_all => 'Do not want to mess up your database by accident' unless $ENV{REDIS_TEST_DATABASE};

my $conn = Convos::Core::Connection->new(server => 'loopback', login => 'doe');
my $loopback = $conn->_irc;

$conn->redis($t->app->redis);

redis_do(
  [ sadd => 'convos:loopback:names', 'doe' ],
  [ zadd => 'user:doe:conversations', time, 'loopback:00:23convos' ],
);

{
  isa_ok $loopback, 'Convos::Loopback';
  is $loopback->nick, '', 'default no nick';
  is $loopback->server, 'loopback', 'server name is loopback';
  is $loopback->user, $loopback->nick, 'user==nick';
  is $loopback->ioloop, $conn->redis->ioloop, 'common ioloop';
  is $loopback->redis, $conn->redis, 'common redis object';
  is $loopback->connection, $conn, 'got connection';
  is $loopback->disconnect, $loopback, 'disconnect() is not implemented';
}

{
  $conn->connect;
  Mojo::IOLoop->timer(0.1, sub { Mojo::IOLoop->stop }); # this will fail...
  Mojo::IOLoop->start;
  is $loopback->nick, 'doe_', 'got nick doe_, since doe was taken';

  ok $loopback->{conversation}{'#convos'}, 'subscribing to #convos';
  ok $loopback->{conversation}{'doe_'}, 'subscribing to doe_';
}

{
  $loopback->change_nick('batman');
  Mojo::IOLoop->timer(0.1, sub { Mojo::IOLoop->stop }); # this will fail...
  Mojo::IOLoop->start;
  is $loopback->nick, 'batman', 'change nick to batman';
}

done_testing;
