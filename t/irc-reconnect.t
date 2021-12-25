#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;

$ENV{CONVOS_CONNECT_DELAY} = 0.1;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new;
my ($connection, $host, $user, %connecting);

$core->start;

$server->subtest(
  'setup' => sub {
    $user = $core->user({email => 'jhthorsen@cpan.org', uid => 42});
    $user->save_p->$wait_success('save user');

    $connection = $user->connection({url => 'irc://example'});
    $connection->save_p->$wait_success('save connection');
  }
);

$server->subtest(
  'close connection from server side after connect' => sub {
    $server->client($connection)->server_event_ok('_irc_event_nick')->process_ok('connect');
    $host       = $connection->url->host;
    %connecting = (message => "Connecting to $host.", state => 'connecting');
    $server->client_states_ok([
      [connection => \%connecting],
      [info       => superhashof({})],
      [connection => {message => "Connected to $host.", state => 'connected'}],
    ]);

    $server->close_connections;
    Mojo::Promise->timer(0.05)->wait;
    $server->client_states_ok([
      [
        connection =>
          {message => 'Connection closed. Reconnecting in 0.1s...', state => 'disconnected'}
      ],
    ]);
  }
);

$server->subtest(
  'connection error' => sub {
    Mojo::Promise->timer(0.3)->wait;
    $server->client_states_ok([
      [connection => \%connecting],
      [info       => superhashof({})],
      [connection => {message => "Connected to $host.", state => 'connected'}],
    ]);

    my $msg;
    $connection->once(message => sub { $msg = $_[2] });
    $connection->{stream}->emit(error => 'Yikes!');
    $server->close_connections;
    is $msg->{message}, 'Yikes! Reconnecting in 0.2s...', 'error event results in a message';
  }
);

$server->subtest(
  'multiple retries' => sub {
    my $port = Mojo::IOLoop::Server->generate_port;
    ok $connection->reconnect_delay <= 0.2, 'reconnect_delay';
    $connection->url(Mojo::URL->new("irc://localhost:$port"));
    $server->client_wait_for_states_ok(8);
    $server->client_states_ok(superbagof(
      [connection => {message => re(qr{Reconnecting in 0\.4s}), state => 'disconnected'}],
      [connection => {message => re(qr{Reconnecting in 0\.8s}), state => 'disconnected'}],
    ));

    $server->client($connection)->server_event_ok('_irc_event_nick')->process_ok('connect');
    $server->client_states_ok(superbagof(
      [connection => {message => re(qr{Connected to \S+}), state => 'connected'}],));
  }
);

done_testing;
