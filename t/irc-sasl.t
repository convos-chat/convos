#!perl
BEGIN { $ENV{CONVOS_SKIP_CONNECT} = 1 }
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new;

my $user = $core->user({email => 'superwoman@example.com'});
$user->save_p->$wait_success;

my $connection = $user->connection({url => 'irc://example'});

$server->subtest(
  'external' => sub {
    $connection->url->userinfo('superwoman:superduper');
    $connection->url->query->param(sasl => 'external');
    $connection->save_p->$wait_success;

    $server->client($connection)->server_event_ok('_irc_event_cap')
      ->server_event_ok('_irc_event_nick')
      ->server_write_ok(":example CAP * LS * :account-notify away-notify chghost extended-join\r\n")
      ->server_write_ok(":example CAP * LS :invite-notify multi-prefix sasl userhost-in-names\r\n")
      ->client_event_ok('_irc_event_cap')->server_event_ok('_irc_event_cap')
      ->server_write_ok(":example CAP superwoman ACK :sasl\r\n")
      ->server_event_ok('_irc_event_authenticate')->server_write_ok(":example AUTHENTICATE +\r\n")
      ->client_event_ok('_irc_event_authenticate')->server_event_ok('_irc_event_authenticate')
      ->server_write_ok(
      ":server 900 superwoman superwoman!superwoman\@localhost superwoman :You are now logged in as superwoman\r\n"
    )->client_event_ok('_irc_event_900')->server_write_ok(['welcome.irc'])
      ->client_event_ok('_irc_event_rpl_welcome')->process_ok('capabilities handshake');

    cmp_deeply(
      $connection->TO_JSON->{info},
      {
        authenticated => true,
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
        certificate => {fingerprint => ''},
        nick        => 'superman',
        real_host   => 'hybrid8.debian.local',
        socket      => ignore,
      },
      'got capabilities',
    );
  }
);

$server->subtest(
  'plain' => sub {
    $connection->url->query->param(sasl => 'plain');
    $connection->disconnect_p->then(sub { $connection->connect_p })->wait;
    is $connection->TO_JSON->{info}{authenticated}, false, 'not authenticated after reconnect';

    $server->client($connection)->server_event_ok('_irc_event_cap')
      ->server_event_ok('_irc_event_nick')
      ->server_write_ok(":example CAP * LS * :account-notify away-notify chghost extended-join\r\n")
      ->server_write_ok(":example CAP * LS :invite-notify multi-prefix sasl userhost-in-names\r\n")
      ->client_event_ok('_irc_event_cap')->server_event_ok('_irc_event_cap')
      ->server_write_ok(":example CAP superwoman ACK :sasl\r\n")
      ->server_event_ok('_irc_event_authenticate')->server_write_ok(":example AUTHENTICATE +\r\n")
      ->client_event_ok('_irc_event_authenticate')->server_event_ok('_irc_event_authenticate')
      ->server_write_ok(
      ":server 900 superwoman superwoman!superwoman\@localhost superwoman :You are now logged in as superwoman\r\n"
    )->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')
      ->process_ok('capabilities handshake');

    is $connection->TO_JSON->{info}{authenticated}, true, 'authenticated';
  }
);

done_testing;
