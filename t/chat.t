BEGIN {
  $ENV{MOJO_IRC_OFFLINE} = 1;
  use File::Temp qw/tempdir/;
  $ENV{CONVOS_ARCHIVE_DIR} = tempdir;
}
use utf8;
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;
use File::Spec::Functions 'catfile';
use Time::Piece ();

my $ts          = Time::Piece->new;
my $channel_log = catfile $ENV{CONVOS_ARCHIVE_DIR}, qw( doe magnet ), '#mojo', $ts->strftime('%y/%m/%d.log');
my $server_log  = catfile $ENV{CONVOS_ARCHIVE_DIR}, qw( doe magnet ), $ts->strftime('%y/%m/%d.log');


redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

my $dom        = Mojo::DOM->new;
my $connection = $t->app->core->ctrl_start(qw( doe magnet ));

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302)
  ->header_is('Location', '/magnet/%23convos', 'Redirect to conversation');

{
  $t->websocket_ok('/socket')->send_ok('yikes');
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li[data-target=""]'), 'Got correct item';
  is $dom->at('li.message.network.error div.content')->text, 'Invalid message (yikes)', 'Invalid message';
}

{
  $t->websocket_ok('/socket')->send_ok('PING')->message_ok->message_is('PONG');    # make sure we are subscribing
  $connection->_irc->from_irc_server(
    ":magnet.llarian.net 353 doe = #convos :fooman {special} \@woman +man [special]\r\n");
  $connection->_irc->from_irc_server(":magnet.llarian.net 366 doe #convos :End of /NAMES list.\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-init[data-network="magnet"][data-target="#convos"]'), 'Got correct names for #convos';
  like $dom, qr{\@woman.*\+man.*fooman}s, 'nicks are sorted';
  is $dom->at('a[href="cmd:///query fooman"][data-nick="fooman"]')->text,       'fooman',    'got fooman';
  is $dom->at('a[href="cmd:///query woman"][data-nick="woman"]')->text,         '@woman',    'got woman';
  is $dom->at('a[href="cmd:///query man"][data-nick="man"]')->text,             '+man',      'got man';
  is $dom->at('a[href="cmd:///query [special]"][data-nick="[special]"]')->text, '[special]', 'got [special]';
  is $dom->at('a[href="cmd:///query {special}"][data-nick="{special}"]')->text, '{special}', 'got {special}';
}

{
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'),
    'Got correct li.message from fooman';
  is $dom->at('h3 a[href="/magnet/fooman"]')->text, 'fooman', 'got message from fooman';
  is $dom->at('.content a')->text, 'http://convos.by?a=1&b=2#yikes', 'http://convos.by#yikes';
  ok $dom->at('a.external[target="_blank"]'), 'got external link';
  like $dom->at('div.content'),
    qr{<div class="content whitespace">doe: see this &amp;amp; link: <a.*href="http://convos\.by\?a=1&amp;b=2\#yikes".*>http://convos\.by\?a=1&amp;b=2\#yikes</a> \# really cool</div>},
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
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct #mojo';
  ok !$dom->at('script'), 'no script tag';
  is $dom->at('div.content'),
    '<div class="content whitespace">&lt;script src=&quot;i/will/take/over.js&quot;&gt;&lt;/script&gt;</div>',
    'no tags';

  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :\x{1}ACTION is too cool\x{1}\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.action.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'),
    'Got correct #mojo';
  ok $dom->at('a[href="/magnet/fooman"]'), 'got action message from fooman';
  is $dom->at('.content')->all_text, '✧ fooman is too cool', 'without special characters';
}

{
  $connection->irc_error({params => ['some error', 'message'],});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message.network.error[data-network="magnet"][data-target=""]'), 'Got IRC error';
  is $dom->at('div.content')->text, 'some error message', 'some error message';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="convos"][data-target=""]'), 'Got IRC error in convos conversation';
  is $dom->at('div.content')->text, 'some error message', 'some error message in convos conversation';
}

{
  $connection->add_server_message({params => ['somenick', 'Your host is Tampa.FL.US.Undernet.org'], command => '123',});
  $dom->parse($t->message_ok->message->[1]);
  ok !$dom->at('li.message.network.error'), 'No server error';
  ok $dom->at('li.message.network.notice[data-network="magnet"][data-target=""]'), 'Got server message';
  is $dom->at('div.content')->text, 'Your host is Tampa.FL.US.Undernet.org', 'Your host is Tampa.FL.US.Undernet.org';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host 311 doe doe john magnet * :Real name\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 317 doe doe 7 :seconds idle\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 319 doe doe :#other #convos\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 319 doe doe :#mojo\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 318 doe doe :End of WHOIS list\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('li.whois[data-network="magnet"][data-target=""]'), 'Got whois';
  is $dom->at('div.content')->all_text,
    'doe (john@magnet - Real name) has been idle for 7 seconds in #other, #convos, #mojo.', 'got whois text'
    or diag $dom;
  ok $dom->at('li.whois[data-network="magnet"][data-target=""] a.nick[href="/magnet/doe"]'), 'got whois /magnet/doe';
  ok $dom->at('li.whois[data-network="magnet"][data-target=""] a.channel[href="/magnet/%23convos"]'),
    'got whois /magnet/%23convos';
  ok $dom->at('li.whois[data-network="magnet"][data-target=""] a.channel[href="/magnet/%23mojo"]'),
    'got whois /magnet/%23mojo';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host 401 me doe :No such nick/channel\r\n");
  $connection->_irc->from_irc_server(":fooman!user\@host 318 me doe :End of WHOIS list\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('li.error[data-network="magnet"][data-target=""]'), 'Could not get whois' or diag $dom;
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
  is $dom->at('div.content')->all_text, 'fooman joined #mojo.', 'fooman joined #mojo';

  $connection->_irc->from_irc_server(":doe!user\@host JOIN #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-add[data-network="magnet"][data-target="#mojo"]'), 'self join #mojo' or diag $dom;

  $connection->_irc->from_irc_server(":doe!user\@host JOIN #mojo\r\n");    # this is ignored

  # run this later to make sure the second JOIN is ignored
  Mojo::IOLoop->timer(0.01, sub { $connection->_irc->from_irc_server(":fooman!user\@host PART #mojo\r\n"); });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-parted[data-network="magnet"][data-target="#mojo"]'), 'user parted' or diag $dom;
  is $dom->at('div.content')->all_text, 'fooman parted #mojo.', 'fooman parted #mojo';

  $connection->_irc->from_irc_server(":doe!user\@host PART #mojo\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-remove[data-network="magnet"][data-target="#mojo"]'), 'self parted' or diag $dom;
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host NICK new_nick\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-change[data-network="magnet"][data-target=""]'), 'nick change';
  is $dom->at('b.old')->text,                           'fooman',   'got old nick';
  is $dom->at('a.nick[href="/magnet/new_nick"]')->text, 'new_nick', 'got new nick';
}

{
  $connection->_irc->from_irc_server(":doe!user\@host 474 doe #mojo :Cannot join channel (+b)\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-network="magnet"][data-target=""]'), 'magnet got banned error';
  is $dom->at('div.content')->all_text, 'Cannot join channel (+b)', 'magnet - Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="convos"][data-target=""]'), 'convos got banned error';
  is $dom->at('div.content')->text, 'Cannot join channel (+b)', 'convos: Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-remove[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 474';

  $connection->_irc->from_irc_server(":doe!user\@host 403 doe #mojo\r\n");
  like $t->message_ok->message->[1], qr{No such channel}, 'No such channel on 403';
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-remove[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 403';

  $connection->_irc->from_irc_server(":doe!user\@host 442 doe #mojo\r\n");
  like $t->message_ok->message->[1], qr{No such channel}, 'No such channel on 442';
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-remove[data-network="magnet"][data-target="#mojo"]'), 'remove conversation on 442';
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
  ok $dom->at('li.error[data-target=""]'), 'Is error';
  is $dom->at('div.content')->all_text, 'Invalid nick', 'Correct error';
}

{
  $connection->_irc->from_irc_server(":fooman!user\@host QUIT :leaving\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-quit[data-network="magnet"][data-target=""]'), 'nick quit';
  is $dom->at('div.content b.nick')->text, 'fooman',  'fooman quit';
  is $dom->at('div.content span')->text,   'Leaving', 'fooman leaving';
}

{
  # Fix parsing links without a path part
  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :http://convos.by is really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);
  like eval { $dom->at('.content a')->text }, qr{^http://convos\.by/?$}, 'not with "is really cool"' or diag $dom;

  # Fix parsing github links
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :[\x{03}13convos\x{0f}] \x{03}15jhthorsen\x{0f} closed issue #132: /query is broken  \x{03}02\x{1f}http://git.io/saYuUg\x{0f}\r\n"
  );
  $dom->parse($t->message_ok->message->[1]);
  like eval { $dom->at('.content a')->text }, qr{^http://git\.io/saYuUg$}, 'without %OF' or diag $dom;

  # Fix parsing links in parens
  $connection->_irc->from_irc_server(":fooman!user\@host PRIVMSG #mojo :This is cool (http://convos.pl)\r\n");
  $dom->parse($t->message_ok->message->[1]);
  like eval { $dom->at('.content a')->text }, qr{^http://convos\.pl/?$}, 'not with ")"' or diag $dom;

  # Fix parsing multiple links in one message
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :this http://perl.org and https://github.com/jhthorsen is cool!\r\n");
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->text, 'this and is cool!',
    '<a href="http://perl.org" target="_blank">http://perl.org</a> https://github.<a href="https://github.com/jhthorsen" target="_blank">https://github.com/jhthorsen</a> yay!';
}

my $log = Mojo::Util::slurp($channel_log);
is int scalar(() = $log =~ /\n/g), 10, 'lines in channel log file';
like $log, qr{^\d+:\d+:\d+ :fooman\!user\@host http://convos\.by is really cool}m, 'log is really cool';
$log = Mojo::Util::slurp($server_log);
is int scalar(() = $log =~ /\n/g), 4, 'lines in server log file';
like $log, qr{Your host is Tampa.FL.US.Undernet.org};

done_testing;
