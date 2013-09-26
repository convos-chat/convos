use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $dom = Mojo::DOM->new;
my $connection = WebIrc::Core::Connection->new(server => 'wirc.pl', login => 'doe');

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:doe:conversations', time, 'wirc:2epl:00:23wirc', time - 1, 'wirc:2epl:00batman' ],
  [ sadd => 'user:doe:connections', 'wirc.pl' ],
  [ hmset => 'user:doe:connection:wirc.pl', nick => 'doe' ],
);

$connection->redis($t->app->redis)->_irc(dummy_irc());
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);
$t->websocket_ok('/socket');

{
  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://wirc.pl?a=1&b=2#yikes # really cool' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-server="wirc.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/4cac29f5fcfe500bc7e9b88e503045b1?s=40&d=retro"]'), 'gravatar image based on user+server';
}

{
  redis_do([ set => 'avatar:user@host', 'jhthorsen' ]);
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="wirc.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//graph.facebook.com/jhthorsen/picture?height=40&width=40"]'), 'facebook avatar' or diag $dom;
}

{
  redis_do([ set => 'avatar:user@host', 'jhthorsen@cpan.org' ]);
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="wirc.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/806800a3aeddbad6af673dade958933b?s=40&d=retro"]'), 'gravatar avatar' or diag $dom;
}

{
  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => '',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-server="wirc.pl"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
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
