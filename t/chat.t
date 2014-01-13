use utf8;
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

my $dom        = Mojo::DOM->new;
my $server     = $t->app->redis->subscribe('convos:user:doe:magnet');
my @data       = data();
my $connection = Convos::Core::Connection->new(name => 'magnet', login => 'doe');

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

$connection->redis($t->app->redis)->_irc(dummy_irc());
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
  $connection->add_message({params => ['#mojo', 'http://convos.by is really cool'], prefix => 'fooman!user@host',});
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.by/"]')->text }, 'http://convos.by/', 'not with "is really cool"'
    or diag $dom;

  # Fix parsing github links
  $connection->add_message(
    {
      params => [
        '#mojo',
        "[\x{03}13convos\x{0f}] \x{03}15jhthorsen\x{0f} closed issue #132: /query is broken  \x{03}02\x{1f}http://git.io/saYuUg\x{0f}"
      ],
      prefix => 'fooman!user@host',
    }
  );
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://git.io/saYuUg"]')->text }, 'http://git.io/saYuUg', 'without %OF' or diag $dom;

  # Fix parsing multiple links in one message
  $connection->add_message(
    {
      params => ['#mojo', "this http://perl.org and https://github.com/jhthorsen is cool!"],
      prefix => 'fooman!user@host',
    }
  );
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->text, 'this and is cool!',
    '<a href="http://perl.org" target="_blank">http://perl.org</a> https://github.<a href="https://github.com/jhthorsen" target="_blank">https://github.com/jhthorsen</a> yay!';
}

{
  $connection->add_message(
    {
      params => ['#mojo', 'doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool'],
      prefix => 'fooman!user@host',
    }
  );
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'),
    'Got correct li.message from fooman';
  is $dom->at('h3 a[href="/magnet/fooman"]')->text, 'fooman', 'got message from fooman';
  is $dom->at('.content a')->text, 'http://convos.by?a=1&b=2#yikes', 'http://convos.by#yikes';
  is $dom->at('div.content'),
    '<div class="content whitespace">doe: see this &amp;amp; link: <a class="embed" href="http://convos.by?a=1&amp;b=2#yikes" target="_blank">http://convos.by?a=1&amp;b=2#yikes</a> # really cool</div>',
    'got link and amp';
  like $dom->at('.timestamp')->text, qr{^\d+\. \S+ [\d\:]+$}, 'got timestamp';

  $connection->add_message(
    {
      params => ['#mojo', "mIRC \x{03}4colors \x{03}4,14http://www.mirc.com/colors.html\x{03} suck imho"],
      prefix => 'fooman!user@host',
    }
  );
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('div.content')->all_text, 'mIRC colors http://www.mirc.com/colors.html suck imho', 'some error message';

  $connection->add_message(
    {params => ['#mojo', 'doe: see this &amp; link: http://magnet/foo really cool'], prefix => 'fooman!user@host',});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('a[href="http://magnet/foo"]'), 'link is without really cool' or diag $dom;

  $connection->add_message(
    {params => ['#mojo', 'doe: see this &amp; link: http://magnet/foo'], prefix => 'fooman!user@host',});
  $dom->parse($t->message_ok->message->[1]);

  ok $dom->at('a[href="http://magnet/foo"]'), 'link is without really cool' or diag $dom;

  $connection->add_message(
    {params => ['#mojo', '<script src="i/will/take/over.js"></script>'], prefix => 'fooman!user@host',});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok !$dom->at('script'), 'no script tag';
  is $dom->at('div.content'),
    '<div class="content whitespace">&lt;script src=&quot;i/will/take/over.js&quot;&gt;&lt;/script&gt;</div>',
    'no tags';

  $connection->add_message({params => ['#mojo', "\x{1}ACTION is too cool\x{1}"], prefix => '',});
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
  $connection->irc_rpl_whoisuser({params => ['', 'doe', 'john', 'magnet', '', 'Real name'],});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.whois[data-network="magnet"][data-target="any"]'), 'Got whois';
  is $dom->at('div.content')->all_text, 'doe is john@magnet (Real name).', 'doe is john@magnet (Real name)';
}

{
  $connection->irc_rpl_whoischannels({params => ['', 'doe', '#other #convos #mojo'],});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.whois[data-network="magnet"][data-target="any"]'), 'Got whois channels';
  is $dom->at('div.content')->all_text, 'doe is in #convos, #mojo, #other.', 'doe is in sorted channels';
}

{
  $connection->irc_rpl_notopic({params => ['', '#convos']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got no topic';
  is $dom->at('div.content')->all_text, 'No topic is set.', 'No topic is set';

  $connection->irc_topic({params => ['#convos', 'Awesome']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got topic';
  is $dom->at('div.content')->all_text, 'Topic is Awesome', 'Awesome topic';
}

{
  $connection->irc_rpl_topic({params => ['', '#convos', 'Speling']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got topic';
  is $dom->at('div.content')->all_text, 'Topic is Speling', 'Speling topic';

  $connection->irc_rpl_topicwhotime({params => ['', '#convos', 'doe', '1375212722']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.topic[data-network="magnet"][data-target="#convos"]'), 'Got topic';
  like $dom->at('div.content')->all_text, qr/Set by doe at 30\. jul\S* \d{2}:32:02/i, 'Set by doe at 30. jul 21:32:02';
}

{
  $connection->irc_join({params => ['#mojo'], prefix => 'fooman!user@host'});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-joined[data-network="magnet"][data-target="#mojo"]'), 'user joined';
  is $dom->at('div.content')->all_text, 'fooman joined #mojo', 'fooman joined #mojo';
}

{
  $connection->irc_nick({params => ['new_nick'], prefix => 'fooman!user@host'});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-change[data-network="magnet"][data-target="any"]'), 'nick change';
  is $dom->at('b.old')->text,                           'fooman',   'got old nick';
  is $dom->at('a.nick[href="/magnet/new_nick"]')->text, 'new_nick', 'got new nick';
}

{
  $connection->irc_part({params => ['#mojo'], prefix => 'fooman!user@host'});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-parted[data-network="magnet"][data-target="#mojo"]'), 'user parted';
  is $dom->at('div.content')->all_text, 'fooman parted #mojo', 'fooman parted #mojo';

  $connection->irc_part({params => ['#mojo'], prefix => 'doe!user@host'});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'self parted';
}

{
  $connection->irc_err_bannedfromchan({params => ['doe', '#mojo', 'Cannot join channel (+b)']});

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-network="magnet"][data-target="any"]'), 'magnet got banned error';
  is $dom->at('div.content')->all_text, 'Cannot join channel (+b)', 'magnet - Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="convos"][data-target="any"]'), 'convos got banned error';
  is $dom->at('div.content')->text, 'Cannot join channel (+b)', 'convos: Cannot join channel (+b)';

  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'remove conversation when banned';
}

for my $m (qw/ irc_err_nosuchchannel irc_err_notonchannel /) {
  $connection->$m({params => ['', '#mojo']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.remove-conversation[data-network="magnet"][data-target="#mojo"]'), 'remove conversation when banned';
}

{
  $connection->cmd_join({params => ['jalla']});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.error[data-target="any"]'), 'invalid join';
  is $dom->at('div.content')->all_text, 'Do not understand which channel to join',
    'do not understand which channel to join';
}

{
  $connection->irc_mode({params => ['#convos', '+o', 'batman']});
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
  $connection->irc_quit({params => ['Quit: leaving'], prefix => 'fooman!user@host'});
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-quit[data-network="magnet"][data-target="any"]'), 'nick quit';
  is $dom->at('div.content b.nick')->text, 'fooman',  'fooman quit';
  is $dom->at('div.content span')->text,   'Leaving', 'fooman leaving';
}

{
  # Fix parsing links without a path part
  $connection->add_message({params => ['#mojo', 'http://convos.by is really cool'], prefix => 'fooman!user@host',});
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.by/"]')->text }, 'http://convos.by/', 'not with "is really cool"'
    or diag $dom;

  # Fix parsing github links
  $connection->add_message(
    {
      params => [
        '#mojo',
        ":gh!~gh\@192.30.252.50 PRIVMSG #convos :[\x{03}13convos\x{0f}] \x{03}15jhthorsen\x{0f} closed issue #132: /query is broken  \x{03}02\x{1f}http://git.io/saYuUg\x{0f}"
      ],
      prefix => 'fooman!user@host',
    }
  );
  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://git.io/saYuUg"]')->text }, 'http://git.io/saYuUg', 'without %OF' or diag $dom;

  # Fix parsing links in parens
  $connection->add_message({params => ['#mojo', 'This is cool (http://convos.pl)'], prefix => 'fooman!user@host',});

  $dom->parse($t->message_ok->message->[1]);
  is eval { $dom->at('a[href="http://convos.pl/"]')->text }, 'http://convos.pl/', 'not with ")"' or diag $dom;
}

done_testing;

sub data {
  irc_rpl_namreply => {params => ['WHATEVER',            'WHATEVER', '#convos', 'fooman @woman'],},
    the_end        => {},     # should never come to this
}

sub dummy_irc {
  no warnings;
  *test::dummy_irc::nick = sub {'doe'};
  *test::dummy_irc::user = sub {''};
  bless {}, 'test::dummy_irc';
}
