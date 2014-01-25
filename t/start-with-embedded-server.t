use t::Helper;
use Mojo::Util qw( spurt );

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

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
  my $backend = $t->app->home->rel_file('backend.tmp');
  like $t->app->{convos_executable_path}, qr{/start-with-embedded-server\.t$}, 'convos_executable_path';
  $t->app->{convos_executable_path} = $backend;
  spurt <<"  APP", $backend;
#!$^X
BEGIN { \$ENV{REDIS_TEST_DATABASE} = "$ENV{REDIS_TEST_DATABASE}" }
use lib 'lib';
use t::Helper;
redis_do set => 'convos:backend:pid' => \$\$;
sleep 4;
  APP
  chmod 0770, $backend;
}

{
  local $SIG{QUIT} = 'DEFAULT';
  local $SIG{USR2};
  start_backend(0.1);
  is redis_do(get => 'convos:backend:lock'),    undef, 'not started: lock is not set';
  is redis_do(get => 'convos:backend:pid'),     undef, 'not started: pid is not set';
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
  like $log[-1], qr{Backend \d+ is running}, 'Backend is running';
}

{
  redis_do(set => 'convos:backend:lock' => 1);
  redis_do(del => 'convos:backend:pid');
  start_backend(0.1);
  like $log[-1], qr{Another process is starting the backend}, 'Another process is starting the backend';
}

{
  my $pid;
  local $SIG{USR2} = 'DEFAULT';

  redis_do(del => 'convos:backend:lock');
  Mojo::IOLoop->recurring(
    0.05 => sub {
      $pid and Mojo::IOLoop->stop;
      redis_do->get('convos:backend:pid' => sub { $pid = pop });
    }
  );
  start_backend(1);

  is redis_do(get => 'convos:backend:lock'), undef, 'external: lock is not set';
  like $pid, qr{^\d+$}, 'external: pid is set';
  ok kill(9, $pid), 'external: killed';

  unlink 'backend.tmp';
}

done_testing;

sub start_backend {
  $t->app->_start_backend;
  Mojo::IOLoop->timer(shift, sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
}
