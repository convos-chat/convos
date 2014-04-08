BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use utf8;
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $dom        = Mojo::DOM->new;
my $server     = $t->app->redis->subscribe('convos:user:doe:magnet');
my $connection = Convos::Core::Connection->new(name => 'magnet', login => 'doe');

my @data = (
  irc_rpl_namreply => {params => ['WHATEVER',            'WHATEVER', '#convos', 'fooman @woman'],},
  the_end          => {},     # should never come to this
);

$server->connect;
$server->on(
  message => sub {
    my ($method, $message) = (shift @data, shift @data);
    $connection->$method($message);
  }
);

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

$connection->_irc->nick('doe');
$connection->redis($t->app->redis);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302)
  ->header_like('Location', qr{/magnet/%23convos$}, 'Redirect to conversation');

{
  $t->websocket_ok('/socket')->send_ok('yikes');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li[data-target="any"]'), 'Got correct 6+any';
  is $dom->at('li.network-message.error div.content')->text, 'Invalid message (yikes)', 'Invalid message';
}

{
  $t->websocket_ok('/socket')
    ->send_ok(
    '<div data-network="magnet" data-target="#test123" id="003cb6af-e826-e17d-6691-3cae034fac1a">/names</div>');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nicks[data-network="magnet"][data-target="#convos"]'), 'Got correct 6+#convos';
  is $dom->at('a[href="/magnet/fooman"][data-nick="fooman"]')->text, 'fooman', 'got fooman';
  is $dom->at('a[href="/magnet/woman"][data-nick="woman"]')->text,   '@woman', 'got woman';
}

{
  # Fix parsing links without a path part
  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :http://convos.by is really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.by/"]')->text }, 'http://convos.by/', 'not with "is really cool"'
    or diag $dom;

  # Fix parsing github links
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :[\x{03}13convos\x{0f}] \x{03}15jhthorsen\x{0f} closed issue #132: /query is broken  \x{03}02\x{1f}http://git.io/saYuUg\x{0f}\r\n"
  );
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://git.io/saYuUg"]')->text }, 'http://git.io/saYuUg', 'without %OF' or diag $dom;

  # Fix parsing multiple links in one message
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :this http://perl.org and https://github.com/jhthorsen is cool!\r\n");
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->text, 'this and is cool!',
    '<a href="http://perl.org" target="_blank">http://perl.org</a> https://github.<a href="https://github.com/jhthorsen" target="_blank">https://github.com/jhthorsen</a> yay!';
}

{
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'),
    'Got correct li.message from fooman';
  is $dom->at('h3 a[href="/magnet/fooman"]')->text, 'fooman', 'got message from fooman';
  is $dom->at('.content a')->text, 'http://convos.by?a=1&b=2#yikes', 'http://convos.by#yikes';
  is $dom->at('div.content'),
    '<div class="content whitespace">doe: see this &amp;amp; link: <a class="embed" href="http://convos.by?a=1&amp;b=2#yikes" target="_blank">http://convos.by?a=1&amp;b=2#yikes</a> # really cool</div>',
    'got link and amp';
  like $dom->at('.timestamp')->text, qr/^\d{1,2}:\d{1,2}$/, 'got timestamp';

  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :mIRC \x{03}4colors \x{03}4,14http://www.mirc.com/colors.html\x{03} suck imho\r\n"
  );
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->all_text, 'mIRC colors http://www.mirc.com/colors.html suck imho', 'some error message';

  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :doe: see this &amp; link: http://magnet/foo really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('a[href="http://magnet/foo"]'), 'link is without really cool' or diag $dom;

  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :doe: see this &amp; link: http://magnet/foo\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('a[href="http://magnet/foo"]'), 'link is without really cool' or diag $dom;

  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :<script src=\"i/will/take/over.js\"></script>\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok !$dom->at('script'), 'no script tag';
  is $dom->at('div.content'),
    '<div class="content whitespace">&lt;script src=&quot;i/will/take/over.js&quot;&gt;&lt;/script&gt;</div>',
    'no tags';

  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :\x{1}ACTION is too cool\x{1}\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'),
    'Got correct 6+#mojo';
  ok $dom->at('a[href="/magnet/fooman"]'), 'got action message from fooman';
  is $dom->at('.content')->all_text, '✧ fooman is too cool', 'without special characters';
}

{
  $connection->irc_error({params => ['some error', 'message'],});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.network-message.error[data-network="magnet"][data-target="any"]'), 'Got IRC error';
  is $dom->at('div.content')->text, 'some error message', 'some error message';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="convos"][data-target="any"]'), 'Got IRC error in convos conversation';
  is $dom->at('div.content')->text, 'some error message', 'some error message in convos conversation';
}

{
  $connection->add_server_message({params => ['somenick', 'Your host is Tampa.FL.US.Undernet.org'], command => '123',});
  $dom->parse($t->message_ok->message->[1]);
  ok !$dom->at('li.network-message.error'), 'No server error';
  ok $dom->at('li.network-message.notice[data-network="magnet"][data-target="any"]'), 'Got server message';
  is $dom->at('div.content')->text, 'Your host is Tampa.FL.US.Undernet.org', 'Your host is Tampa.FL.US.Undernet.org';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host 311 doe doe john magnet * :Real name\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 317 doe doe 7 :seconds idle\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 319 doe doe :#other #convos\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 319 doe doe :#mojo\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 318 doe doe :End of WHOIS list\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('li.whois[data-network="magnet"][data-target="any"]'), 'Got whois';
  is $dom->at('div.content')->all_text,
    'doe (john@magnet - Real name) has been idle for 7 seconds in #other, #convos, #mojo.', 'got whois text'
    or diag $dom;
  ok $dom->at('li.whois[data-network="magnet"][data-target="any"] a[class="nick"][href="/magnet/doe"]'),
    'got whois /magnet/doe';
  ok $dom->at('li.whois[data-network="magnet"][data-target="any"] a[class="channel"][href="/magnet/%23convos"]'),
    'got whois /magnet/%23convos';
  ok $dom->at('li.whois[data-network="magnet"][data-target="any"] a[class="channel"][href="/magnet/%23mojo"]'),
    'got whois /magnet/%23mojo';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host 401 me doe :No such nick/channel\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 318 me doe :End of WHOIS list\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('li.error[data-network="magnet"][data-target="any"]'), 'Could not get whois' or diag $dom;
  is $dom->at('div.content')->all_text, 'No such nick: doe', 'doe is probably offline.' or diag $dom;
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host 331 doe #convos :No topic is set.\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got no topic';
  is $dom->at('div.content')->all_text, 'No topic is set.', 'No topic is set';

  $connection->_irc->from_irc_server(":fooman!user\@host 332 doe #convos :Awesome\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got topic';
  is $dom->at('div.content')->all_text, 'Topic is Awesome', 'Awesome topic';

  $connection->_irc->from_irc_server(":fooman!user\@host 333 doe #convos doe 1375212722\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got topic';
  like $dom->at('div.content')->all_text, qr/Set by doe at 30\. jul\S* \d{2}:32:02/i, 'Set by doe at 30. jul 21:32:02';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host JOIN #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-joined[data-network="magnet"][data-target="#mojo"]'), 'user joined';
  is $dom->at('div.content')->all_text, 'fooman joined #mojo', 'fooman joined #mojo';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host NICK new_nick\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-change[data-network="magnet"][data-target="any"]'), 'nick change';
  is $dom->at('b.old')->text,                           'fooman',   'got old nick';
  is $dom->at('a.nick[href="/magnet/new_nick"]')->text, 'new_nick', 'got new nick';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host PART #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-parted[data-network="magnet"][data-target="#mojo"]'), 'user parted' or diag $dom;
  is $dom->at('div.content')->all_text, 'fooman parted #mojo', 'fooman parted #mojo';

  $connection->_irc->from_irc_server(":doe!user\@host PART #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'self parted' or diag $dom;
}

{
  $connection->_irc->from_irc_server(":doe!user\@host 474 doe #mojo :Cannot join channel (+b)\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-network="magnet"][data-target="any"]'), 'magnet got banned error';
  is $dom->at('div.content')->all_text, 'Cannot join channel (+b)', 'magnet - Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="convos"][data-target="any"]'), 'convos got banned error';
  is $dom->at('div.content')->text, 'Cannot join channel (+b)', 'convos: Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 474';

  $connection->_irc->from_irc_server(":doe!user\@host 403 doe #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 403';

  $connection->_irc->from_irc_server(":doe!user\@host 442 doe #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 442';
}

{
  $connection->cmd_join({params => ['jalla']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-target="any"]'), 'invalid join';
  is $dom->at('div.content')->all_text, 'Do not understand which channel to join',
    'do not understand which channel to join';
}

{
  $connection->_irc->from_irc_server(":doe!user\@host MODE #convos +o batman\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.notice[data-network="magnet"][data-target="#convos"]'), 'mode to #convos';
  is $dom->at('div.content b')->text,    '+o',     'op for...';
  is $dom->at('div.content span')->text, 'batman', 'op for batman';
}

{
  $connection->cmd_nick({params => ['TheMack']});
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->text, 'Set nick to TheMack', 'Nick set correctly';
}
{
  $connection->cmd_nick({params => ['TheM@ck']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-target="any"]'), 'Is error';
  is $dom->at('div.content')->all_text, 'Invalid nick', 'Correct error';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host QUIT :leaving\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-quit[data-network="magnet"][data-target="any"]'), 'nick quit';
  is $dom->at('div.content b.nick')->text, 'fooman',  'fooman quit';
  is $dom->at('div.content span')->text,   'Leaving', 'fooman leaving';
}

{
  # Fix parsing links without a path part
  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :http://convos.by is really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.by/"]')->text }, 'http://convos.by/', 'not with "is really cool"'
    or diag $dom;

  # Fix parsing github links
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo ::gh!~gh\@192.30.252.50 PRIVMSG #convos :[\x{03}13convos\x{0f}] \x{03}15jhthorsen\x{0f} closed issue #132: /query is broken  \x{03}02\x{1f}http://git.io/saYuUg\x{0f}\r\n"
  );
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://git.io/saYuUg"]')->text }, 'http://git.io/saYuUg', 'without %OF' or diag $dom;

  # Fix parsing links in parens
  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :This is cool (http://convos.pl)\r\n");

  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.pl/"]')->text }, 'http://convos.pl/', 'not with ")"' or diag $dom;
}

done_testing;

