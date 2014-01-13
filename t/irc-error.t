use t::Helper;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

my $port = Mojo::IOLoop->generate_port;
my $core = $t->app->core;
my $conn;

redis_do(
  [hmset => 'user:doe',                            digest => 'E2G3goEIb8gpw', email => ''],
  [srem  => 'user:doe:connections',                "localhost:$port"],
  [hmset => "user:doe:connection:localhost:$port", nick   => 'doe',           host  => "localhost:$port"],
);

{
  no warnings 'redefine';
  *Convos::Core::Connection::_reconnect_in = sub { Mojo::IOLoop->stop; 0.01 };
}

{
  $core->ctrl_start('doe', "localhost:$port");
  Mojo::IOLoop->start;
  ok $conn = $core->{connections}{doe}{"localhost:$port"}, 'connection added';
  ok !$conn->_irc->{stream}, 'irc has no stream';
}

Mojo::IOLoop->server(
  {port => $port},
  sub {
    my ($ioloop, $stream) = @_;
    Mojo::IOLoop->timer(0.01 => sub { $stream->close });
  },
);

{
  no warnings 'redefine';
  $core->ctrl_start('doe', "localhost:$port");
  Mojo::IOLoop->start;
  ok !$conn->_irc->{stream}, 'irc has no stream';
}

{
  no warnings 'redefine';
  $core->ctrl_start('doe', "localhost:$port");
  Mojo::IOLoop->start;
}

done_testing;
