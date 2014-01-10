BEGIN {
  *CORE::GLOBAL::exec = sub { sleep 100 };
}

use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $t_pid = $$;
my @log;

$t->app->log->on(message => sub { shift; shift; push @log, @_; });

{
  no warnings 'redefine';
  *Convos::Core::start = sub {
    my $core = shift;
    $core->redis->incr('convos:backend:started');
    Mojo::IOLoop->stop unless $$ == $t_pid;
  };
}

{
  local $SIG{QUIT} = 'DEFAULT';
  local $SIG{USR2};
  start_backend(0.1);
  is redis_do(get => 'convos:backend:lock'), undef, 'not started: lock is not set';
  is redis_do(get => 'convos:backend:pid'), undef, 'not started: pid is not set';
  is redis_do(get => 'convos:backend:started'), undef, 'not started: backend was not started';
  like $log[-1], qr{Backend is not running .* not be automatically}, 'Backend is not running';
}

{
  start_backend(0.1);
  is redis_do(get => 'convos:backend:lock'), undef, 'embedded: lock is not set';
  is redis_do(get => 'convos:backend:pid'), $$, 'embedded: pid is set';
  is redis_do(get => 'convos:backend:started'), 1, 'embedded: core got started';
}

{
  start_backend(0.1);
  like $log[-1], qr{Backend is running}, 'Backend is running';
}

{
  redis_do(set => 'convos:backend:lock' => 1);
  redis_do(del => 'convos:backend:pid');
  start_backend(0.1);
  like $log[-1], qr{Another process is starting the backend}, 'Another process is starting the backend';
}

{
  local $SIG{USR2} = 'DEFAULT';
  redis_do(del => 'convos:backend:lock');
  start_backend(0.1);
  my $pid = redis_do(get => 'convos:backend:pid');
  is redis_do(get => 'convos:backend:lock'), undef, 'external: lock is not set';
  like $pid, qr{^\d+$}, 'external: pid is set';
  ok kill(QUIT => $pid), 'external: sent QUIT';

  Mojo::IOLoop->timer(1 => sub {
    diag "Timeout!";
    kill 9, $pid;
    Mojo::IOLoop->stop;
  });

  Mojo::IOLoop->recurring(0.01 => sub {
    kill 0, $pid and return;
    Mojo::IOLoop->stop;
  });

  Mojo::IOLoop->start;

  ok !kill(0 => $pid), 'external: backend completed';
}

done_testing;

sub start_backend {
  $t->app->_start_backend;
  Mojo::IOLoop->timer(shift, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
}
