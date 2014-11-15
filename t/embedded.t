BEGIN { $ENV{MOJO_MODE} = 'production' }
use t::Helper;
use Test::Mojo;
use Test::More;
use File::Spec;
use Convos::Core;

delete $SIG{USR2};
$ENV{CONVOS_BACKEND_EMBEDDED} = 1;
$ENV{TMPDIR}                  = 't';

unlink 't/convos-backend.pid';
plan skip_all => 'Custom TMPDIR is required' unless File::Spec->tmpdir eq $ENV{TMPDIR};

no warnings 'redefine';
my $start = 0;
*Convos::Core::start = sub { $start++ };

my $t = Test::Mojo->new('Convos');
ok $t->app->{pid_file}, 'first convos started backend';
ok -e 't/convos-backend.pid', 'pid file written';

{
  my $t2 = Test::Mojo->new('Convos');
  ok !$t2->app->{pid_file}, 'second convos did not start backend';
}

is $start, 1, 'core is started once';

done_testing;
