use lib 'lib';
use Test::More;
plan skip_all => 'Devel::Cover' if $ENV{HARNESS_PERL_SWITCHES} ~~ /Devel::Cover/;
eval 'use Test::Pod; 1' or plan skip_all => 'Test::Pod required';
all_pod_files_ok();
