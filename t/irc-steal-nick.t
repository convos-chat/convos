#!perl
use lib '.';
use t::Helper;

BEGIN { $ENV{CONVOS_IRC_PERIDOC_INTERVAL} = 0.1 }
use Convos::Core;

my $core       = Convos::Core->new;
my $user       = $core->user({email => 'nick.young@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $nick       = '';

t::Helper->irc_server_connect($connection);

$connection->on(state => sub { return unless $_[1] eq 'me'; $nick = $_[2]->{nick}; });

note 'change nick to nick_young_';
t::Helper->irc_server_messages(
  qr{NICK nick_young\b} =>
    ":hybrid8.debian.local 433 * nick_young :Nickname is already in use.\r\n",
  qr{NICK nick_young_\b} => ":hybrid8.debian.local 001 nick_young_ :Welcome\r\n",
);
is $connection->url->query->param('nick'), 'nick_young', 'nick_young set in connect url';
is $connection->{myinfo}{nick}, 'nick_young_', 'connection nick nick_young_';

note 'NICK command sent by recurring timer';
t::Helper->irc_server_messages(
  qr{NICK nick_young\b} => ":nick_young_!superman\@i.love.debian.org NICK :nick_young\r\n",
  $connection           => '_irc_event_nick',
);
is $connection->url->query->param('nick'), 'nick_young', 'nick_young set in connect url';
is $connection->{myinfo}{nick}, 'nick_young', 'connection nick nick_young';

note 'change nick';
$connection->send_p('', '/nick n2');
t::Helper->irc_server_messages(
  qr{NICK n2} => ":nick_young!superman\@i.love.debian.org NICK :n2\r\n",
  $connection => '_irc_event_nick',
);
is $connection->url->query->param('nick'), 'n2', 'n2 set in connect url';
is $connection->{myinfo}{nick}, 'n2', 'connection nick n2';

done_testing;
