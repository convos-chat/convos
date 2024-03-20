#!perl
use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;

$ENV{TEST_ALL} //= $ENV{RELEASE};

plan skip_all => 'TEST_ALL=1'            unless $ENV{TEST_ALL};
plan skip_all => 'Changes was not found' unless -r 'Changes';

my ($perl_wanted, $date) = path('Changes')->slurp =~ /^(\d+\.\d+\w*)\s+(.*)/m;

my $node_wanted = $perl_wanted;
$node_wanted =~ s!\.0+!.0!g;
$node_wanted .= '.0' unless $node_wanted =~ s!_0*(\d+)!.$1!;
$node_wanted =~ s!\.0([1-9])!.$1!g;

my $failed = 0;
$failed += like($date, qr/^\d{4}-/, 'correct date in Changes') ? 0 : 1;

if ($ENV{RELEASE}) {
  BAIL_OUT 'Incorrect date in Changes' if $failed;

  require Tie::File;
  tie my @f, 'Tie::File', 'lib/Convos.pm' or die $!;
  s!^(\d+\.\d+$)!$perl_wanted! or s!VERSION\s*=\s*'\d+\.\d+'!VERSION='$perl_wanted'! for @f;
  untie @f;

  tie @f, 'Tie::File', 'script/convos' or die $!;
  s!^(\d+\.\d+$)!$perl_wanted! or s!VERSION\s*=\s*'\d+\.\d+'!VERSION='$perl_wanted'! for @f;
  untie @f;

  tie @f, 'Tie::File', 'package.json' or die $!;
  s!"version":\s*"\d+\.\d+.\d+"!"version": "$node_wanted"! for @f;
  untie @f;

  tie @f, 'Tie::File', 'snap/snapcraft.yaml' or die $!;
  s!version:\s*'\d+\.\d+.\d+'!version: '$node_wanted'! for @f;
  untie @f;

  tie @f, 'Tie::File', 'public/convos-api.yaml' or die $!;
  s!version:\s*\S+!version: $node_wanted! for @f;
  untie @f;
}

require Convos;
$failed += is($Convos::VERSION, $perl_wanted, 'correct version in Convos.pm code') ? 0 : 1;

my ($pod_version) = path($INC{'Convos.pm'})->slurp =~ /^(\d+\.\d+\w*)\s/m;
$failed += is($pod_version, $perl_wanted, 'correct version in Convos.pm pod') ? 0 : 1;

my ($script_version) = path($INC{'Convos.pm'})->slurp =~ /^(\d+\.\d+\w*)\s/m;
$failed += is($script_version, $perl_wanted, 'correct version in script/convos') ? 0 : 1;

my ($node_version) = path('package.json')->slurp =~ /"version":\s*"([^"]+)/m;
$failed += is($node_version, $node_wanted, 'correct version in package.json') ? 0 : 1;

my ($snap_version) = path(qw(snap snapcraft.yaml))->slurp =~ /^version:\s*'([^']+)/m;
$failed += is($snap_version, $node_wanted, 'correct version in snap/snapcraft.yaml') ? 0 : 1;

my ($api_version) = path(qw(public convos-api.yaml))->slurp =~ /\sversion:\s*(\S+)/m;
$failed += is($api_version, $node_wanted, 'correct version in public/convos-api.yaml') ? 0 : 1;

if ($ENV{RELEASE} and !$failed) {
  system(git => add    => 'public')                             and exit $?;
  system(git => commit => -a => -m => "Released v$perl_wanted") and exit $?;
  system(git => tag    => "v$perl_wanted")                      and exit $?;
  print <<'HERE';

  All files updated correctly.

  Now run:

  $ git push origin main:main; git push origin main:stable; git push origin --tags


HERE
}

done_testing;
