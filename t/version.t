#!perl
use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;
use Convos;

plan skip_all => 'TEST_ALL=1'            unless $ENV{TEST_ALL};
plan skip_all => 'Changes was not found' unless -r 'Changes';

my ($wanted_version) = path('Changes')->slurp =~ /^(\d+\.\d+\w*)\s/m;
is $Convos::VERSION, $wanted_version, 'correct version in Convos.pm code';

my ($pod_version) = path($INC{'Convos.pm'})->slurp =~ /^(\d+\.\d+\w*)\s/m;
is $pod_version, $wanted_version, 'correct version in Convos.pm pod';

$wanted_version =~ s!\.0+!.!g;
$wanted_version .= '.0' unless $wanted_version =~ s!_0*(\d+)!.$1!;
my ($node_version) = path('package.json')->slurp =~ /"version":\s*"([^"]+)/m;
is $node_version, $wanted_version, 'correct version in package.json';

my ($snap_version) = path(qw(snap snapcraft.yaml))->slurp =~ /^version:\s*'([^']+)/m;
is $snap_version, $wanted_version, 'correct version in snap/snapcraft.yaml';

my ($api_version) = path(qw(public convos-api.json))->slurp =~ /\s"version":\s*"([^"]+)/m;
is $api_version, $wanted_version, 'correct version in public/convos-api.json';

done_testing;
