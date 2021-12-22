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

$server->client($connection);

$server->subtest(
  'change nick to nick_young_' => sub {
    $server->server_event_ok('_irc_event_nick')
      ->server_write_ok(":hybrid8.debian.local 433 * nick_young :Nickname is already in use.\r\n")
      ->server_event_ok('_irc_event_nick')
      ->server_write_ok(":hybrid8.debian.local 001 nick_young_ :Welcome\r\n")
      ->client_event_ok('_irc_event_rpl_welcome')->process_ok('nick_young_');

    is $connection->url->query->param('nick'), 'nick_young',  'nick_young set in connect url';
    is $connection->info->{nick},              'nick_young_', 'connection nick nick_young_';
  }
);

$server->subtest(
  'NICK command sent by recurring timer' => sub {
    $server->server_event_ok('_irc_event_nick')
      ->server_write_ok(":nick_young_!superman\@i.love.debian.org NICK :nick_young\r\n")
      ->client_event_ok('_irc_event_nick')->process_ok('nick_young');
    is $connection->url->query->param('nick'), 'nick_young', 'nick_young set in connect url';
    is $connection->info->{nick},              'nick_young', 'connection nick nick_young';
  }
);

$server->subtest(
  'change nick' => sub {
    $server->server_event_ok('_irc_event_nick')
      ->server_write_ok(":nick_young!superman\@i.love.debian.org NICK :n2\r\n")
      ->client_event_ok('_irc_event_nick');
    $connection->send_p('', '/nick n2')->$wait_success;
    $server->process_ok;
    is $connection->url->query->param('nick'), 'n2', 'n2 set in connect url';
    is $connection->info->{nick},              'n2', 'connection nick n2';
  }
);

done_testing;
