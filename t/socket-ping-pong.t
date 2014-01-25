BEGIN { $ENV{CONVOS_PING_INTERVAL} = 0.1 }
use t::Helper;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

{
  diag 'login first';
  redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],);

  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
}

{
  my $frame;
  $t->ua->websocket(
    '/socket' => {'Sec-Websocket-Extensions' => 'none'},
    sub {
      my ($ua, $tx) = @_;
      $tx->on(
        frame => sub {
          $frame = $_[1];
          Mojo::IOLoop->stop;
        }
      );
    }
  );

  Mojo::IOLoop->start;
  is $frame->[4], 1, 'sent as message';
  is $frame->[5], '<div class="ping"/>', 'Avoid browser ping/pong to prevent browser errors (Chrome!#$%!)';
}

#warn $t->message->[1];

done_testing;
