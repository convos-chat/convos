use t::Helper;
use Convos::Command::backend;

my $backend = Convos::Command::backend->new;


{
  eval { $backend->run('stop') };
  like $@, qr{MOJO_MODE need to be set}, 'MOJO_MODE need to be set';
}

$ENV{MOJO_MODE} = 'development';

for my $action (qw( start stop restart )) {
  no strict 'refs';
  no warnings 'redefine';
  my $called;
  local *{"Convos::Command::backend::_action_$action"} = sub { $called++; };
  $backend->run($action);
  is $called, 1, "run $action";
}

is $backend->_action_stop, 1, 'backend is stopped';

done_testing;
