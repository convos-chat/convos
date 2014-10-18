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
  $connection->_irc->from_irc_server(":some.irc.server 433 doe newnick :Nickname is already in use.\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('.message.network.error'), 'server error';
  is $dom->at('.content')->text, 'Nickname is already in use.', 'Nickname is already in use.';

  $connection->_irc->from_irc_server(":some.irc.server 433 doe newnick :Nickname is already in use.\r\n");
  $connection->_irc->from_irc_server(":doe!user\@host 331 doe #convos :No topic is set.\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok !$dom->at('.message.network.error'), 'supress err_nicknameinuse';
  ok $dom->at('li.topic'), 'got topic instead';

  $connection->_irc->nick('doe');
  $connection->_irc->from_irc_server(":doe!user\@host NICK whatever\r\n");
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.nick-change[data-network="magnet"][data-target=""]'), 'nick change';

  $connection->_irc->from_irc_server(":some.irc.server 433 whatever something :Nickname is already in use.\r\n");
  $dom->parse($t->message_ok->message->[1]);
  is $dom->at('.content')->text, 'Nickname is already in use.', 'err_nicknameinuse is back after nick change';
}

done_testing;
