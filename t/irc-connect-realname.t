#!perl
BEGIN { $ENV{CONVOS_SKIP_CONNECT} = 1 }
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;
use Test::Deep;

use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;
use Test::Deep;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user   = $core->user({email => 'test.user@example.com'});
$user->save_p->$wait_success;

my $connection = $user->connection({url => 'irc://example'});
$connection->url->query->param(nick     => '_superman');
$connection->url->query->param(realname => 'Clark Kent');
$connection->save_p->$wait_success;

my $test_user_command = sub {
  my ($conn, $msg) = @_;
  is_deeply $msg->{params}, ['xsuperman', '0', '*', 'Clark Kent via https://convos.chat'],
    'got expected USER command';
};

$server->client($connection)->server_event_ok('_irc_event_nick')
  ->server_event_ok('_irc_event_user', $test_user_command)->server_write_ok(['welcome.irc'])
  ->client_event_ok('_irc_event_rpl_welcome')->process_ok;

$connection->disconnect_p->$wait_success('disconnect_p');
$connection->url->query->param(nick => 'Superman');

my $test_User_command = sub {
  my ($conn, $msg) = @_;
  is_deeply $msg->{params}, ['Superman', '0', '*', 'Clark Kent via https://convos.chat'],
    'got expected USER command';
};

$server->client($connection)->server_event_ok('_irc_event_nick')
  ->server_event_ok('_irc_event_user', $test_User_command)->server_write_ok(['welcome.irc'])
  ->client_event_ok('_irc_event_rpl_welcome')->process_ok;

done_testing;
