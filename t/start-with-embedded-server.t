use Mojo::Base -base;
use Test::More;
use Convos;

$ENV{CONVOS_BACKEND_PID_FILE} = File::Spec->catfile(File::Spec->tmpdir, 'convos-test-backend.pid');
$ENV{CONVOS_REDIS_URL} = 'localhost:123456789';

{
  local $SIG{USR2} = sub { };                # emulate hypnotoad (hackish)
  local $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  eval { Convos->new };
  like $@, qr{Cannot start embedded backend from hypnotoad}, 'cannot start CONVOS_BACKEND_EMBEDDED with hypnotoad';
}

{
  my ($start, $got_pid) = (0, 0);
  local $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  local *Convos::Core::start = sub {
    $got_pid = -e $ENV{CONVOS_BACKEND_PID_FILE};
    $start++;
  };
  eval { Convos->new };
  is $start, 1, 'backend started';
  ok !-e $ENV{CONVOS_BACKEND_PID_FILE}, 'pid file was cleaned up';
  ok $got_pid, 'pid file was created';
}

done_testing;
