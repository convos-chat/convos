BEGIN {
  unless ($ENV{REAL_AVATARS}) {
    $ENV{DEFAULT_AVATAR_URL}  = '/image/avatar-convos.jpg';
    $ENV{GRAVATAR_AVATAR_URL} = '/image/avatar-convos.jpg';
  }
}
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

my $dom = Mojo::DOM->new;
my $connection = Convos::Core::Connection->new(name => 'magnet', login => 'doe');

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

{
  unlink glob('/tmp/convos/*');
  $t->get_ok('/avatar/jan.henning@thorsen.pm')->status_is(200)->header_is('Content-Type', 'image/jpeg');
  unlink glob('/tmp/convos/*');
  $t->get_ok('/avatar/doe')->status_is(200)->header_is('Content-Type', 'image/jpeg');
  unlink glob('/tmp/convos/*');
  $t->get_ok('/avatar/invalid')->status_is(404);
}

$connection->redis($t->app->redis)->_irc(dummy_irc());
$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
$t->get_ok('/')->status_is(302)->header_like(Location => qr{:\d+/magnet/%23convos});

done_testing;

sub dummy_irc {
  no warnings;
  *test::dummy_irc::nick = sub {'doe'};
  *test::dummy_irc::user = sub {''};
  bless {}, 'test::dummy_irc';
}
