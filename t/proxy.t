use Test::More;
use Mojo::IOLoop;
use Mojo::IRC;
use WebIrc::Core;
use Mojo::Redis;
use strict;
use warnings;



my $redis= setup_test();
my $core = WebIrc::Core->new(redis => $redis);
$core->start;
use_ok('WebIrc::Proxy');
my $proxy = WebIrc::Proxy->new(core => $core);
isa_ok($proxy, 'WebIrc::Proxy');
can_ok($proxy, 'start');
my $port = Mojo::IOLoop->generate_port;
$proxy->port($port);
$proxy->start(
  sub {
    warn('Proxy started');
    my $client = Mojo::IOLoop->client(
      {port => $port},
      sub {
        my ($loop, $err, $stream) = @_;
        warn("Connected");
        ok(1, 'connected');
        $stream->close;
      }
    );
    my $irc = Mojo::IRC->new(nick => 'test', user => 'test', pass => 'testing', host => "localhost:$port");
    warn('Connecting to ' . $irc->server);
    $irc->on(
      irc_rpl_namreply=> sub {
        my ($self, $message) = @_;
        is($message->{params}[2], '#wirc', 'Joined #wirc');
        Mojo::IOLoop->stop;
      }
    );
    $irc->on(
      close => sub {
        my ($self) = @_;
        ok(0, 'Connection closed');
        Mojo::IOLoop->stop;
      }
    );
    $irc->connect(
      sub {
        my ($irc, $err) = @_;
        ok(!$err, 'Connected ok');
        diag("Err:" . $err);
      }
    );
  }
);
Mojo::IOLoop->start;
done_testing;


sub setup_test {
  my $t=shift;
  my $redis = Mojo::Redis->new(server => 'redis://127.0.0.1:6379/1');
  $redis->flushall;
  return $redis;
}