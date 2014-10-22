BEGIN {
  $ENV{CONVOS_BACKEND_ONLY} = 1;
  $ENV{CONVOS_CONNECT_INTERVAL} //= 0.02;
}
use t::Helper;

my $port      = Mojo::IOLoop::Server->generate_port;
my $core      = $t->app->core;
my $connected = 0;

for my $name (qw( magnet freenode whatever )) {
  my $conn = {login => 'batman', name => $name, nick => 'batman', server => "localhost:$port"};

  $core->add_connection($conn, sub { $conn = $_[1]; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  ok eval { !$conn->has_error }, "connection $name added";
}

local *Convos::Core::Connection::_reconnect = sub {
  $connected++;
  Mojo::IOLoop->stop;
};

$core->start;
Mojo::IOLoop->start;
is $connected, 1, 'only one connected';

Mojo::IOLoop->start;
is $connected, 2, 'second connection connected';

Mojo::IOLoop->start;
is $connected, 3, 'third connection connected';

is_deeply(
  [sort { $a <=> $b } map { $_->{core_connect_timer} } values %{$core->{connections}}],
  [-2, -1, 0],
  'core_connect_timer',
);

done_testing;
