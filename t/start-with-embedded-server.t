use Test::More;
use Test::Mojo;
use Time::HiRes qw( usleep );

$ENV{MOJO_MODE} = 'production';
$ENV{POLL_FOR_INVALID_PARENT} = 0.01;
$ENV{BACKEND_PID};

*CORE::GLOBAL::getppid = sub { -42 };
my $t = Test::Mojo->new('Convos');

{
  ok $t->app->backend_pid, 'backend has forked';
  $ENV{BACKEND_PID} = $t->app->backend_pid;
}

{
  $SIG{ALRM} = sub { die "Waited too long for child pid" };
  alarm 1;
  wait;
  alarm;
  ok !kill(0, $ENV{BACKEND_PID}), 'backend died because of parent pid change' and delete $ENV{BACKEND_PID};
}

done_testing;

END {
  warn kill 9, $ENV{BACKEND_PID} if $ENV{BACKEND_PID};
}
