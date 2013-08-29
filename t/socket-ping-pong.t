BEGIN { $ENV{WIRC_PING_INTERVAL} = 0.1 }
use t::Helper;

{
  diag 'login first';
  redis_do(
    [ set => 'user:doe:uid', 42 ],
    [ hmset => 'user:42', digest => 'E2G3goEIb8gpw', email => '' ],
  );

  $t->post_ok('/', form => { login => 'doe', password => 'barbar' });
}

{
  my $frame;
  $t->ua->websocket('/socket' => sub {
    my($ua, $tx) = @_;
    $tx->on(frame => sub {
      $frame = $_[1];
      Mojo::IOLoop->stop;
    });
  });

  Mojo::IOLoop->start;
  is $frame->[4], 9, 'got ping from server';
  is $frame->[5], 'pin', 'why just "pin" ? because i am crazy! mohahaha!';
}

#warn $t->message->[1];

done_testing;
