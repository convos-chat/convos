use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $dom = Mojo::DOM->new;
my $server = $t->app->redis->subscribe('connection:6:to_server');
my @data = data();
my $connection = WebIrc::Core::Connection->new;
my $i = 0;

$server->on(message => sub {
  my($method, $message) = (shift @data, shift @data);
  diag "$i --- $method";
  $i++;
  $connection->$method($message);
});

redis_do(
  [ set => 'user:doe:uid', 42 ],
  [ hmset => 'user:42', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:42:conversations', time, '6:00:23wirc', time - 1, '6:00batman' ],
  [ sadd => 'user:42:connections', 6 ],
  [ hmset => 'connection:6', nick => 'doe' ],
);

$connection->id(6)->uid(42)->redis($t->app->redis)->_irc(dummy_irc());
$t->post_ok('/', form => { login => 'doe', password => 'barbar' })->header_like('Location', qr{/6/%23wirc$}, 'Redirect to conversation');

{
  $t->websocket_ok('/socket')->send_ok('yikes');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li[data-cid="0"][data-target="any"]'), 'Got correct cid+any';
  is $dom->at('li.server-message.error div.content')->text, 'Invalid message: (yikes)', 'Invalid message: (yikes)';
}

{
  $t->websocket_ok('/socket')->send_ok('<div data-cid="123" data-target="#test123" id="003cb6af-e826-e17d-6691-3cae034fac1a">/names</div>');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li[data-cid="0"][data-target="any"]'), 'Got correct cid+any';
  is $dom->at('li.server-message.error div.content')->text, 'Not allowed to subscribe to 123', 'Not allowed to subscribe to 123';
}

{
  $t->websocket_ok('/socket')->send_ok('<div data-cid="6" data-target="#test123" id="003cb6af-e826-e17d-6691-3cae034fac1a">/names</div>');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nicks[data-cid="6"][data-target="#wirc"]'), 'Got correct 6+#wirc';
  is $dom->at('a[href="/6/fooman"][data-nick="fooman"]')->text, 'fooman', 'got fooman';
  is $dom->at('a[href="/6/woman"][data-nick="woman"]')->text, '@woman', 'got woman';
}

{
  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://wirc.pl?a=1&b=2#yikes # really cool' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-cid="6"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/4cac29f5fcfe500bc7e9b88e503045b1?s=40&d=retro"]'), 'gravatar image based on user+host';
  is $dom->at('h3 a[href="/6/fooman"]')->text, 'fooman', 'got message from fooman';
  is $dom->at('a[href="http://wirc.pl?a=1&b=2#yikes"]')->text, 'http://wirc.pl?a=1&b=2#yikes', 'http://wirc.pl#yikes';
  is $dom->at('div.content'), '<div class="content whitespace">doe: see this &amp;amp; link: <a href="http://wirc.pl?a=1&amp;b=2#yikes" target="_blank">http://wirc.pl?a=1&amp;b=2#yikes</a> # really cool</div>', 'got link and amp';
  like $dom->at('.timestamp')->text, qr{^\d+\. \S+ [\d\:]+$}, 'got timestamp';

  $connection->add_message({
    params => [ '#mojo', "mIRC \x{3}4colors \x{3}4,14http://www.mirc.com/colors.html\x{3} suck imho" ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->all_text, 'mIRC colors http://www.mirc.com/colors.html suck imho', 'some error message';

  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://wirc.pl/foo really cool' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('a[href="http://wirc.pl/foo"]'), 'link is without really cool' or diag $dom;

  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://wirc.pl/foo' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('a[href="http://wirc.pl/foo"]'), 'link is without really cool' or diag $dom;

  $connection->add_message({
    params => [ '#mojo', '<script src="i/will/take/over.js"></script>' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-cid="6"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok !$dom->at('script'), 'no script tag';
  is $dom->at('div.content'), '<div class="content whitespace">&lt;script src=&quot;i/will/take/over.js&quot;&gt;&lt;/script&gt;</div>', 'no tags';



  $connection->add_message({
    params => [ '#mojo', "\x{1}ACTION is too cool\x{1}" ],
    prefix => '',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-cid="6"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="//gravatar.com/avatar/0000000000000000000000000000?s=40&d=retro"]'), 'default gravatar image';
  ok $dom->at('a[href="/6/fooman"]'), 'got action message from fooman';
  is $dom->at('.content')->all_text, 'fooman is too cool', 'without special characters';
}

{
  $connection->irc_error({
    params => [ 'some error', 'message' ],
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.server-message.error[data-cid="6"][data-target="any"]'), 'Got IRC error';
  is $dom->at('div.content')->text, 'some error message', 'some error message';
}

{
  $connection->add_server_message({
    params => ['somenick', 'Your host is Tampa.FL.US.Undernet.org'],
  });
  $dom->parse($t->message_ok->message->[1]);
  ok !$dom->at('li.server-message.error'), 'No server error';
  ok $dom->at('li.server-message.notice[data-cid="6"][data-target="any"]'), 'Got server message';
  is $dom->at('div.content')->text, 'Your host is Tampa.FL.US.Undernet.org', 'Your host is Tampa.FL.US.Undernet.org';
}

{
  $connection->irc_rpl_whoisuser({
    params => ['', 'doe', 'john', 'wirc.pl', '', 'Real name'],
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.whois[data-cid="6"][data-target="any"]'), 'Got whois';
  is $dom->at('div.content')->all_text, 'doe is john@wirc.pl (Real name).', 'doe is john@wirc.pl (Real name)';
}

{
  $connection->irc_rpl_whoischannels({
    params => ['', 'doe', '#wirc #mojo #other'],
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.whois[data-cid="6"][data-target="any"]'), 'Got whois channels';
  is $dom->at('div.content')->all_text, 'doe is in #mojo, #other, #wirc.', 'doe is in sorted channels';
}

{
  $connection->irc_rpl_notopic({ params => ['', '#wirc'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-cid="6"][data-target="#wirc"]'), 'Got no topic';
  is $dom->at('div.content')->all_text, 'No topic is set.', 'No topic is set';

  $connection->irc_topic({ params => ['#wirc', 'Awesome'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-cid="6"][data-target="#wirc"]'), 'Got topic';
  is $dom->at('div.content')->all_text, 'Topic is Awesome', 'Awesome topic';
}

{
  $connection->irc_rpl_topic({ params => ['', '#wirc', 'Speling'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-cid="6"][data-target="#wirc"]'), 'Got topic';
  is $dom->at('div.content')->all_text, 'Topic is Speling', 'Speling topic';

  $connection->irc_rpl_topicwhotime({ params => ['', '#wirc', 'doe', '1375212722'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-cid="6"][data-target="#wirc"]'), 'Got topic';
  like $dom->at('div.content')->all_text, qr/Set by doe at 30\. jul\S* 21:32:02/i, 'Set by doe at 30. jul 21:32:02';
}

{
  $connection->irc_join({ params => [ '#mojo' ], prefix => 'fooman!user@host' });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-joined[data-cid="6"][data-target="#mojo"]'), 'user joined';
  is $dom->at('div.content')->all_text, 'fooman joined #mojo', 'fooman joined #mojo';

  $connection->irc_join({ params => [ '#mojo' ], prefix => 'doe!user@host' });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.add-conversation[data-cid="6"][data-target="#mojo"]'), 'self joined';
}

{
  $connection->irc_nick({ params => [ 'new_nick' ], prefix => 'fooman!user@host' });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-change[data-cid="6"][data-target="any"]'), 'nick change';
  is $dom->at('b.old')->text, 'fooman', 'got old nick';
  is $dom->at('a.nick[href="/6/new_nick"]')->text, 'new_nick', 'got new nick';
}

{
  $connection->irc_part({ params => [ '#mojo' ], prefix => 'fooman!user@host' });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-parted[data-cid="6"][data-target="#mojo"]'), 'user parted';
  is $dom->at('div.content')->all_text, 'fooman parted #mojo', 'fooman parted #mojo';

  $connection->irc_part({ params => [ '#mojo' ], prefix => 'doe!user@host' });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-cid="6"][data-target="#mojo"]'), 'self parted';
}

{
  $connection->irc_err_bannedfromchan({ params => [ 'doe', '#mojo', 'Cannot join channel (+b)' ] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-cid="6"][data-target="#mojo"]'), 'remove conversation when banned';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.notice[data-cid="0"][data-target="any"]'), 'banned notice';
  is $dom->at('div.content')->all_text, 'Cannot join channel (+b)', 'wirc - Cannot join channel (+b)';
}

for my $m (qw/ irc_err_nosuchchannel irc_err_notonchannel /) {
  $connection->$m({ params => [ '', '#mojo' ] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-cid="6"][data-target="#mojo"]'), 'remove conversation when banned';
}

{
  $connection->cmd_join({ params => ['jalla'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.notice[data-cid="0"][data-target="any"]'), 'invalid join';
  is $dom->at('div.content')->all_text, 'Do not understand which channel to join', 'wirc - Do not understand which channel to join';

  $connection->cmd_join({ params => ['#perl'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.add-conversation[data-cid="6"][data-target="#perl"]'), 'joined';
}

{
  $connection->irc_mode({ params => ['#wirc', '+o', 'batman'] });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.notice[data-cid="6"][data-target="#wirc"]'), 'mode to #wirc';
  is $dom->at('div.content b')->text, '+o', 'op for...';
  is $dom->at('div.content span')->text, 'batman', 'op for batman';
}

done_testing;

sub data {
  irc_rpl_namreply => {
    params => [ 'WHATEVER', 'WHATEVER', '#wirc', 'fooman @woman' ],
  },
  the_end => {}, # should never come to this
}

sub msg {
  qq(<div data-history="1" data-cid="6" data-target="#wirc">$_[0]</div>);
}

sub dummy_irc {
  *test::dummy_irc::nick = sub { 'doe' };
  *test::dummy_irc::user = sub { '' };
  bless {}, 'test::dummy_irc';
}
