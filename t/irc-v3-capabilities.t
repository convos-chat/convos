#!perl
BEGIN { $ENV{CONVOS_SKIP_CONNECT} = 1 }
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new;
my $user   = $core->user({email => 'superwoman@example.com'});
$user->save_p->$wait_success;

note 'external';
my $connection = $user->connection({name => 'example', protocol => 'irc'});
$connection->url->userinfo('superwoman:superduper');
$connection->save_p->$wait_success;

$server->client($connection)->server_event_ok('_irc_event_cap')->server_event_ok('_irc_event_nick')
  ->server_write_ok(":example CAP * LS * :account-notify away-notify chghost extended-join\r\n")
  ->server_write_ok(":example CAP * LS :invite-notify multi-prefix sasl userhost-in-names\r\n")
  ->client_event_ok('_irc_event_cap')->server_event_ok('_irc_event_cap')
  ->server_write_ok(
  "example 900 superwoman superwoman!superwoman\@localhost superwoman :You are now logged in as superwoman\r\n"
)->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')
  ->process_ok('capabilities handshake');

is_deeply $connection->TO_JSON->{me},
  {
  authenticated => false,
  nick          => 'superman',
  capabilities  => {
    'account-notify'    => true,
    'away-notify'       => true,
    'chghost'           => true,
    'extended-join'     => true,
    'invite-notify'     => true,
    'multi-prefix'      => true,
    'sasl'              => true,
    'userhost-in-names' => true,
  },
  real_host => 'hybrid8.debian.local',
  },
  'got capabilities';

done_testing;
