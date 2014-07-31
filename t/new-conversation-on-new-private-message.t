use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $dom        = Mojo::DOM->new;
my $connection = Convos::Core::Connection->new(login => 'doe', name => 'magnet');
my $messages   = $t->app->redis->subscribe('convos:user:doe:out');

$messages->on(message => sub { Mojo::IOLoop->stop });

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

$connection->redis($t->app->redis);
$connection->_irc->nick('doe')->user('');
$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})
  ->header_is('Location', '/magnet/%23convos', 'Redirect to conversation');
$t->websocket_ok('/socket');

{
  $connection->add_message({params => ['doe', 'really cool'], prefix => 'fooman!user@host'});
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="fooman"][data-sender="fooman"]'), 'private message';

  Mojo::IOLoop->timer(1, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.conversation-add[data-network="magnet"][data-target="fooman"]'), 'new private message';

  $connection->add_message({params => ['doe', 'really cool'], prefix => 'fooman!user@host'});
  Mojo::IOLoop->timer(1, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-network="magnet"][data-target="fooman"][data-sender="fooman"]'),
    'just the message the second time';

  $t->finish_ok;
}

{
  $t->get_ok('/magnet/%23convos')->status_is(200)->element_exists('nav li:nth-of-child(2) a[href="/magnet/%23convos"]')
    ->text_is('nav li:nth-of-child(3) a[href="/magnet/fooman"] b', 2)->text_is('nav li a[href="/magnet/fooman"] b', 2)
    ->element_exists('nav li:nth-of-child(4) a[href="/magnet/batman"]');
}

done_testing;
