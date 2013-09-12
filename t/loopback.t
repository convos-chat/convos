use t::Helper;
use Test::More;
use WebIrc::Loopback;
use WebIrc::Core::Connection;

my $conn = WebIrc::Core::Connection->new(server => 'loopback', login => 'doe');
my $loopback = $conn->_irc;

$conn->redis($t->app->redis);

redis_do(
  [ sadd => 'wirc:loopback:names', 'doe' ],
  [ zadd => 'user:doe:conversations', time, 'loopback:00:23wirc' ],
);

{
  isa_ok $loopback, 'WebIrc::Loopback';
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

  ok $loopback->{conversation}{'#wirc'}, 'subscribing to #wirc';
  ok $loopback->{conversation}{'doe_'}, 'subscribing to doe_';
}

{
  $loopback->change_nick('batman');
  Mojo::IOLoop->timer(0.1, sub { Mojo::IOLoop->stop }); # this will fail...
  Mojo::IOLoop->start;
  is $loopback->nick, 'batman', 'change nick to batman';
}

done_testing;
