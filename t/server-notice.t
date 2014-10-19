BEGIN {
  use File::Temp 'tempdir';
  $ENV{CONVOS_ARCHIVE_DIR} = tempdir;
  $ENV{MOJO_IRC_OFFLINE}   = 1;
}
use utf8;
use t::Helper;
use Mojo::DOM;

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
  $t->websocket_ok('/socket')->send_ok('PING')->message_ok->message_is('PONG');    # make sure we are subscribing
  $connection->_irc->from_irc_server(
    ":spectral.shadowcat.co.uk NOTICE doe :*** Connected securely via TLSv1 AES128-SHA-128\r\n");

  $dom->parse($t->message_ok->message->[1]);
  ok !$dom->at('.message.private.highlight'), 'not a private message';
  ok $dom->at('.message.network.notice'), 'server notice';
  is $dom->at('.content')->text, '*** Connected securely via TLSv1 AES128-SHA-128', 'correct notice';

  # this is rather fragile, but it's the best I can come up with at the moment
  Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  $t->send_ok('PING')->message_ok->message_is('PONG', 'no add_conversation message');
}

done_testing;
