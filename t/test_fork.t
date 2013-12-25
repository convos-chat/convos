use Test::More;
use Test::Mojo;
use File::Basename qw( basename );


$ENV{MOJO_MODE} = 'production';
my $t = Test::Mojo->new('Convos');
ok($t->app->backend_pid, 'Backend has forked');
kill 9,$t->app->backend_pid;
done_testing;;
