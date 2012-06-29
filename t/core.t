use Test::More;
use Mojo::Redis;

use_ok('WebIrc::Core');
my $redis=Mojo::Redis->new(server=>'127.0.0.1:6379');
populate_redis($redis);
my $core=WebIrc::Core->new(redis=>$redis);
$core->start;

done_testing;

sub populate_redis {
  my $redis=shift;
  $redis->del('connections');
}