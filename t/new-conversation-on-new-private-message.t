use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

t::Helper->capture_redis_errors;
t::Helper->init_database;

my $dom = Mojo::DOM->new;
my $connection = WebIrc::Core::Connection->new;
my $messages = $t->app->redis->subscribe('connection:6:from_server');

$messages->on(message => sub { Mojo::IOLoop->stop; });

redis_do(
  [ set => 'user:doe:uid', 42 ],
  [ hmset => 'user:42', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:42:conversations', time, '6:00:23wirc', time - 1, '6:00batman' ],
  [ sadd => 'user:42:connections', 6 ],
  [ hmset => 'connection:6', nick => 'doe' ],
);

$connection->id(6)->uid(42)->redis($t->app->redis);
$connection->_irc->nick('doe')->user('');
$t->post_ok('/', form => { login => 'doe', password => 'barbar' })->header_like('Location', qr{/6/%23wirc$}, 'Redirect to conversation');
$t->websocket_ok('/socket');

{
  $connection->add_message({ params => [ 'doe', 'really cool' ], prefix => 'fooman!user@host' });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-cid="6"][data-target="fooman"][data-sender="fooman"]'), 'private message';

  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.add-conversation[data-cid="6"][data-target="fooman"]'), 'new private message';

  $connection->add_message({ params => [ 'doe', 'really cool' ], prefix => 'fooman!user@host' });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-cid="6"][data-target="fooman"][data-sender="fooman"]'), 'just the message the second time';

  $t->finish_ok;
}

{
  $t->get_ok('/conversations')
    ->element_exists('li:nth-of-child(1) a[data-unread="0"][href="/6/%23wirc"]')
    ->element_exists('li:nth-of-child(2) a[data-unread="2"][href="/6/fooman"]')
    ->element_exists('li.unread a[data-unread="2"][href="/6/fooman"]')
    ->element_exists('li:nth-of-child(3) a[data-unread="0"][href="/6/batman"]')
    ;
}

done_testing;
