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
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/4cac29f5fcfe500bc7e9b88e503045b1?s=40&d=retro"]'), 'gravatar image based on user+server';
}

{
  redis_do([ set => 'avatar:user@host', 'jhthorsen' ]);
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="convos.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//graph.facebook.com/jhthorsen/picture?height=40&width=40"]'), 'facebook avatar' or diag $dom;
}

{
  redis_do([ set => 'avatar:user@host', 'jhthorsen@cpan.org' ]);
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="convos.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/806800a3aeddbad6af673dade958933b?s=40&d=retro"]'), 'gravatar avatar' or diag $dom;
}

{
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => '',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="convos.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/0000000000000000000000000000?s=40&d=retro"]'), 'default gravatar image';
}

$t->finish_ok;

done_testing;

sub dummy_irc {
  no warnings;
  *test::dummy_irc::nick = sub { 'doe' };
  *test::dummy_irc::user = sub { '' };
  bless {}, 'test::dummy_irc';
}
