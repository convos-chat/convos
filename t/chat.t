use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

t::Helper->capture_redis_errors;
t::Helper->init_database;

my $dom = Mojo::DOM->new;
my $json = Mojo::JSON->new;
my $server = $t->app->redis->subscribe('connection:6:to_server');
my @data = data();

$server->on(message => sub {
  $t->app->redis->publish('connection:6:from_server' => $json->encode(shift @data));
});

redis_do(
  [ set => 'user:doe:uid', 42 ],
  [ hmset => 'user:42', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:42:conversations', time, '6:00:23wirc', time - 1, '6:00batman' ],
  [ sadd => 'user:42:connections', 6 ],
  [ hmset => 'connection:6', nick => 'doe' ],
);

$t->post_ok('/', form => { login => 'doe', password => 'barbar' })->header_like('Location', qr{/6/%23wirc$}, 'Redirect to conversation');

$t->websocket_ok('/socket')->send_ok('yikes')->message_ok;
$dom->parse($t->message->[1]);
ok $dom->at('li[data-cid="0"][data-target="any"]'), 'Got correct 6+any';
is $dom->at('li.server-message.error span')->text, 'Error - Not allowed to subscribe to', 'Error - Not allowed to subscribe to';

$t->websocket_ok('/socket')->send_ok(msg('/names'))->message_ok;
$dom->parse($t->message->[1]);
ok $dom->at('li.nicks[data-cid="6"][data-target="#wirc"]'), 'Got correct 6+#wirc';
is $dom->at('a[href="/6/fooman"][data-nick="fooman"]')->text, 'fooman', 'got fooman';
is $dom->at('a[href="/6/woman"][data-nick="woman"]')->text, '@woman', 'got woman';

$t->app->redis->publish('connection:6:from_server' => $json->encode(shift @data));
$t->websocket_ok('/socket')->message_ok;
$dom->parse($t->message->[1]);
ok $dom->at('li.message[data-cid="6"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
ok $dom->at('img[alt="fooman"][src="https://secure.gravatar.com/avatar/23799a05dda548f5a6cf77e23d28418e?s=40&d=retro"]'), 'default gravatar image';
is $dom->at('h3 a[href="/6/fooman"]')->text, 'fooman', 'got message from fooman';
is $dom->at('a[href="http://google.com"]')->text, 'http://google.com', 'got google link';
is $dom->at('.timestamp')->text, '29. juli 23:30:12', 'got timestamp';

$t->finish_ok;

done_testing;

sub data {
  {
    cid => 6,
    target => '#wirc',
    event => 'rpl_namreply',
    timestamp => 1375133412,
    nicks => [
      { nick => 'fooman', mode => '' },
      { nick => 'woman', mode => '@' },
    ],
  },
  {
    cid => 6,
    target => '#mojo',
    event => 'message',
    nick => 'fooman',
    timestamp => 1375133412,
    message => 'doe: see this link: http://google.com',
  },
  {
    the_end => 1,
  },
}

sub msg {
  qq(<div data-history="1" data-cid="6" data-target="#wirc">$_[0]</div>);
}
