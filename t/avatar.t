BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use utf8;
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $dom        = Mojo::DOM->new;
my $server     = $t->app->redis->subscribe('convos:user:doe:magnet');
my $connection = Convos::Core::Connection->new(name => 'magnet', login => 'doe');
my $elem;

$server->connect;

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

$connection->_irc->nick('doe');
$connection->redis($t->app->redis);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302)
  ->header_is('Location', '/magnet/%23convos', 'Redirect to conversation')->websocket_ok('/socket');

{
  $connection->_irc->from_irc_server(
    ":fooman!user\@host PRIVMSG #mojo :doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $elem = $dom->at('li.message i.fa-user'), 'i';
  is $elem->{'style'}, 'color:#8bad7c', 'i[style]';
  is $elem->{'data-avatar'}, 'https://gravatar.com/avatar/4cac29f5fcfe500bc7e9b88e503045b1?s=40&d=retro',
    'i[data-avatar]';
}

{
  redis_do [hmset => 'user:jhthorsen', avatar => 'jhthorsen@cpan.org', email => ''];
  $connection->_irc->from_irc_server(
    ":fooman!~jhthorsen\@host PRIVMSG #mojo :doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool\r\n"
  );
  $dom->parse($t->message_ok->message->[1]);

  ok $elem = $dom->at('li.message i.fa-user'), 'i';
  is $elem->{'style'}, 'color:#ec305a', 'i[style]';
  is $elem->{'data-avatar'}, 'https://gravatar.com/avatar/806800a3aeddbad6af673dade958933b?s=40&d=retro',
    'i[data-avatar]';
}

{
  redis_do [hmset => 'user:doe', avatar => 'jhthorsen', email => ''];
  $connection->_irc->from_irc_server(":fooman!doe\@host PRIVMSG #mojo :\x{1}ACTION is too cool\x{1}\r\n");
  $dom->parse($t->message_ok->message->[1]);

  ok $elem = $dom->at('li.message i.fa-user'), 'i';
  is $elem->{'style'}, 'color:#b43a22', 'i[style]';
  is $elem->{'data-avatar'}, 'https://graph.facebook.com/jhthorsen/picture?height=40&width=40', 'i[data-avatar]';
}

done_testing;
