use Test::More;
use Mojo::IOLoop;



use_ok('WebIrc::Proxy');
my $proxy=WebIrc::Proxy->new;
isa_ok($proxy,'WebIrc::Proxy');
can_ok($proxy,'start');
my $port=Mojo::IOLoop->generate_port;
$proxy->port($port);
$proxy->start;
my $client=Mojo::IOLoop->client({ port => $port}, sub {
  my ($loop,$err,$stream)=@_;
  $stream->on(read=>sub {
    my ($stream,$chunk)=@_;
  });
  Mojo::IOLoop->stop;
  ok(1,'connected');
});
Mojo::IOLoop->start;
done_testing;
