use t::Helper;
use Mojo::DOM;

{
  diag 'login first';
  redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],);

  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
}

{
  my $message;
  $t->ua->websocket(
    '/socket' => {'Sec-Websocket-Extensions' => 'none'},
    sub {
      my ($ua, $tx) = @_;

      $tx->on(
        message => sub {
          Mojo::IOLoop->stop;
          $message = $_[1];
          $tx->close;
        }
      );

      $tx->send(q(<div id="123" data-target="" data-network="some.host">/ping convos</div>));
    }
  );

  Mojo::IOLoop->start;
  $message = Mojo::DOM->new($message);
  is $message->find('li.pong')->size, 1, 'Got pong response' or diag $message;
}

#warn $t->message->[1];

done_testing;
