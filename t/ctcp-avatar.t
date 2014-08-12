BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use t::Helper;

redis_do(
  [zadd => 'user:user1:conversations', time, 'magnet:00:23convos'],
  [sadd => 'user:user1:connections',   'magnet'],
  [hmset => 'user:user1:connection:magnet', nick => 'doe'],
  [zadd => 'user:user1:conversations', time, 'magnet:00:23convos'],
  [sadd => 'user:user1:connections',   'magnet'],
  [hmset => 'user:user1:connection:magnet', nick => 'doe'],
);

# set convos:frontend:url
$t->get_ok('/')->status_is(302);

my $user1 = Convos::Core::Connection->new(name => 'magnet', login => 'user1');
my $user2 = Convos::Core::Connection->new(name => 'magnet', login => 'user2');

$user1->_irc->nick('user1nick');
$user1->{convos_frontend_url} = redis_do get => 'convos:frontend:url';
$user2->_irc->nick('user2nick');
$user2->{convos_frontend_url} = redis_do get => 'convos:frontend:url';

$user1->add_message(
  {
    uuid    => 'test123',
    command => 'privmsg',
    prefix  => 'user2nick!user2@irc.example.com',
    params  => ['#convos', 'hey user1'],
  }
);

diag "send request to user2";
like $user1->_irc->{to_irc_server}, qr{PRIVMSG user2nick :\x{1}AVATAR\x{1}\r\n}, 'sent PRIVMSG AVATAR';

diag "receive request from user1";
$user2->_irc->from_irc_server("user1nick!user1\@localhost " . $user1->_irc->{to_irc_server});
like $user2->_irc->{to_irc_server}, qr{NOTICE user1nick :\x{1}AVATAR http://localhost:\d+/avatar\x{1}\r\n},
  'sent NOTICE AVATAR';

done_testing;
