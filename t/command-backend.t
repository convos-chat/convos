use Mojo::Base -base;
use Test::More;
use Convos::Command::backend;
use Convos;
use Cwd;

$ENV{CONVOS_BACKEND_ONLY}     = 1;
$ENV{CONVOS_BACKEND_PID_FILE} = File::Spec->catfile(File::Spec->tmpdir, 'convos-test-backend.pid');
$ENV{CONVOS_REDIS_URL}        = 'localhost:12345678';

my $backend = Convos::Command::backend->new(app => Convos->new);
my $daemon = $backend->_daemon;

is $daemon->fork, 2, 'fork=2';
is $daemon->help,     $backend->usage,       'help';
is $daemon->lsb_desc, $backend->description, 'lsb_desc';
like $daemon->program, qr{script\W+convos-backend$}, 'program';
ok -x $daemon->program, 'full path to program';
is $daemon->pid_file, $ENV{CONVOS_BACKEND_PID_FILE}, 'pid_file';
is $daemon->init_config, '/etc/default/convos', 'init_config';
is $daemon->directory, getcwd, 'directory';

no warnings 'redefine';

{
  my ($started, $pid) = (0, 0);

  is $daemon->read_pid, 0, 'no pid written';

  local *Convos::Core::start = sub {
    Mojo::IOLoop->timer(
      0 => sub {
        $started++;
        $pid = $daemon->read_pid;
        $pid = undef unless -r $daemon->pid_file;
        Mojo::IOLoop->stop;
      }
    );
  };

  $backend->run('-f');
  is $started, 1, 'backend started in foreground';
  is $pid, $$, 'pid written by foreground process';
  ok -e $daemon->pid_file, 'pid_file exists';
}

{
  my $exit_value = 0;
  local *Convos::Command::backend::_exit = sub { $exit_value = $_[1]; };
  local *Daemon::Control::run_command = sub { $_[1]; };

  $backend->run('start');
  is $exit_value, 'start', 'extra arguments are passed on to Daemon::Control';
}

{
  undef $backend;
  ok !-e $daemon->pid_file, 'pid_file removed on DESTROY';
}

done_testing;
