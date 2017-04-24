#!perl
use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;
use Convos;

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};
plan skip_all => 'Changes was not found' unless -r 'Changes';

my ($wanted_version) = path('Changes')->slurp =~ /^(\d+\.\d+\w*)\s/m;
my ($pod_version)    = path($INC{'Convos.pm'})->slurp =~ /^(\d+\.\d+\w*)\s/m;
my ($snap_version)   = path('snap/snapcraft.yaml')->slurp =~ /^version:\s*'([^']+)/m;

is $Convos::VERSION, $wanted_version, 'correct version in Convos.pm code';
is $pod_version,     $wanted_version, 'correct version in Convos.pm pod';

$wanted_version =~ s!_(\d+)!.$1!;
is $snap_version, $wanted_version, 'correct version in snap/snapcraft.yaml';

done_testing;
