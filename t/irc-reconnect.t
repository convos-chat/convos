#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new;
my ($connection, $host, $user, %connecting);

$core->connect_delay(0.1)->start;

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
    is $core->connect_queue_size, 0, 'nothing in queue';
    $server->client($connection)->server_event_ok('_irc_event_nick')->process_ok('connect');
    $host       = $connection->url->host;
    %connecting = (message => "Connecting to $host...", state => 'connecting');
    $server->client_states_ok([
      [connection => \%connecting],
      [info       => superhashof({})],
      [connection => {message => "Connected to $host.", state => 'connected'}],
    ]);

    $server->close_connections;
    Mojo::Promise->timer(0.05)->wait;
    is $core->connect_queue_size, 1, 'one connection is waiting to connect';
    $server->client_states_ok([
      [
        connection => {
          message => 'Connection closed. Reconnecting after 1 seconds...',
          state   => 'disconnected'
        }
      ],
    ]);
  }
);

$server->subtest(
  'connection error' => sub {
    is $core->connect_queue_size, 1, 'one item in queue after close above';
    $core->_dequeue;
    Mojo::Promise->timer(0.3)->wait;
    is $core->connect_queue_size, 0, 'nothing in queue after reconnect';
    $server->client_states_ok([
      [connection => \%connecting],
      [info       => superhashof({})],
      [connection => {message => "Connected to $host.", state => 'connected'}],
    ]);

    $connection->{stream}->emit(error => 'Yikes!');
    $server->close_connections;
    $server->client_states_ok([
      [
        connection => {message => 'Yikes! Reconnecting after 1 seconds...', state => 'disconnected'}
      ],
    ]);
  }
);

done_testing;
