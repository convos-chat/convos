use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $dom = Mojo::DOM->new;
my $connection = Convos::Core::Connection->new(login => 'doe', server => 'irc.perl.org');
my $messages = $t->app->redis->subscribe('convos:user:doe:out');

$messages->on(message => sub { Mojo::IOLoop->stop });

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:doe:conversations', time, 'irc:2eperl:2eorg:00:23convos', time - 1, 'irc:2eperl:2eorg:00batman' ],
  [ sadd => 'user:doe:connections', 'irc.perl.org' ],
  [ hmset => 'user:doe:connection:irc.perl.org', nick => 'doe' ],
);

$connection->redis($t->app->redis);
$connection->_irc->nick('doe')->user('');
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->header_like('Location', qr{/irc.perl.org/%23convos$}, 'Redirect to conversation');
$t->websocket_ok('/socket');

{
  $connection->add_message({ params => [ 'doe', 'really cool' ], prefix => 'fooman!user@host' });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-server="irc.perl.org"][data-target="fooman"][data-sender="fooman"]'), 'private message';

  Mojo::IOLoop->timer(1, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.add-conversation[data-server="irc.perl.org"][data-target="fooman"]'), 'new private message';

  $connection->add_message({ params => [ 'doe', 'really cool' ], prefix => 'fooman!user@host' });
  Mojo::IOLoop->timer(1, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-server="irc.perl.org"][data-target="fooman"][data-sender="fooman"]'), 'just the message the second time';

  $t->finish_ok;
}

{
  $t->get_ok('/conversations')
    ->element_exists('li:nth-of-child(1) a[data-unread="0"][href="/irc.perl.org/%23convos"]')
    ->element_exists('li:nth-of-child(2) a[data-unread="2"][href="/irc.perl.org/fooman"]')
    ->element_exists('li.unread a[data-unread="2"][href="/irc.perl.org/fooman"]')
    ->element_exists('li:nth-of-child(3) a[data-unread="0"][href="/irc.perl.org/batman"]')
    ;
}

done_testing;
