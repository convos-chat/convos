BEGIN {
  unless($ENV{REAL_AVATARS}) {
    $ENV{DEFAULT_AVATAR_URL} = '/image/avatar-convos.jpg';
    $ENV{GRAVATAR_AVATAR_URL} = '/image/avatar-convos.jpg';
  }
}
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $dom = Mojo::DOM->new;
my $connection = Convos::Core::Connection->new(server => 'convos.pl', login => 'doe');

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:doe:conversations', time, 'convos:2epl:00:23convos', time - 1, 'convos:2epl:00batman' ],
  [ sadd => 'user:doe:connections', 'convos.pl' ],
  [ hmset => 'user:doe:connection:convos.pl', nick => 'doe' ],
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
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);
$t->websocket_ok('/socket');

{
  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://convos.pl?a=1&b=2#yikes # really cool' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-server="convos.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="/avatar/user@host"]'), 'gravatar image based on user+host';
}

{
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="convos.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="/avatar/user@host"]'), 'default gravatar image';
}

$t->finish_ok;

done_testing;

sub dummy_irc {
  no warnings;
  *test::dummy_irc::nick = sub { 'doe' };
  *test::dummy_irc::user = sub { '' };
  bless {}, 'test::dummy_irc';
}
