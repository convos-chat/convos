#!perl
BEGIN { $ENV{CONVOS_IRC_PERIDOC_INTERVAL} = 0.1 }

use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;

my $server     = t::Server::Irc->new->start;
my $core       = Convos::Core->new;
my $user       = $core->user({email => 'nick.young@example.com'});
my $connection = $user->connection({url => 'irc://localhost'});
my $nick       = '';

$connection->on(state => sub { return unless $_[1] eq 'me'; $nick = $_[2]->{nick}; });
$server->client($connection);

note 'change nick to nick_young_';
$server->server_event_ok('_irc_event_nick')
  ->server_write_ok(":hybrid8.debian.local 433 * nick_young :Nickname is already in use.\r\n")
  ->server_event_ok('_irc_event_nick')
  ->server_write_ok(":hybrid8.debian.local 001 nick_young_ :Welcome\r\n")
  ->client_event_ok('_irc_event_rpl_welcome')->process_ok('nick_young_');

is $connection->url->query->param('nick'), 'nick_young', 'nick_young set in connect url';
is $connection->{myinfo}{nick}, 'nick_young_', 'connection nick nick_young_';

note 'NICK command sent by recurring timer';
$server->server_event_ok('_irc_event_nick')
  ->server_write_ok(":nick_young_!superman\@i.love.debian.org NICK :nick_young\r\n")
  ->client_event_ok('_irc_event_nick')->process_ok('nick_young');
is $connection->url->query->param('nick'), 'nick_young', 'nick_young set in connect url';
is $connection->{myinfo}{nick}, 'nick_young', 'connection nick nick_young';

note 'change nick';
$server->server_event_ok('_irc_event_nick')
  ->server_write_ok(":nick_young!superman\@i.love.debian.org NICK :n2\r\n")
  ->client_event_ok('_irc_event_nick');
$connection->send_p('', '/nick n2')->$wait_success;
$server->process_ok;
is $connection->url->query->param('nick'), 'n2', 'n2 set in connect url';
is $connection->{myinfo}{nick}, 'n2', 'connection nick n2';

done_testing;
