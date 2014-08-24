BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use t::Helper;

redis_do(
  [zadd => 'user:user1:conversations', time, 'magnet:00:23test'],
  [sadd => 'user:user1:connections',   'magnet'],
  [hmset => 'user:user1:connection:magnet', nick => 'doe'],
);

my $user = Convos::Core::Connection->new(name => 'magnet', login => 'user1');
$user->redis($t->app->redis);
$user->cmd_join({params => ['#test', 'key']});
$user->irc_rpl_welcome({});
Mojo::IOLoop->timer(
  0.1 => sub {
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
like($user->_irc->{to_irc_server}, qr/JOIN #test key/, 'Welcome join remembers specified key');
done_testing;
