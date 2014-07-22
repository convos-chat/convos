#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojo::Base -strict;
use Mojo::Log;
use Convos;

chdir "$FindBin::Bin/..";
$ENV{MOJO_MODE}      ||= 'production';
$ENV{MOJO_LOG_LEVEL} ||= 'info';
$ENV{CONVOS_MANUAL_BACKEND} = $ENV{CONVOS_SKIP_VERSION_CHECK} = 1;

Mojo::Log->new->info("Running with MOJO_MODE=$ENV{MOJO_MODE}");

my $days_to_keep  = shift or die "\nUsage: $0 <days-to-keep>\n";
my $remove_before = time - 86400 * $days_to_keep;
my $human         = localtime $remove_before;
my $app           = Convos->new;
my $redis         = $app->redis;
my ($flush, @keys);

$flush = sub {
  my $redis = shift;
  my $key = shift @keys or return $redis->ioloop->stop;

  local $| = 1;
  print '.';
  $redis->zremrangebyscore($key => "-inf", "($remove_before", $flush);
};

$redis->execute(
  'keys',
  'user:*:connection:*:msg',
  sub {
    my ($redis, $keys) = @_;
    @keys = @$keys;
    $app->log->info("Will flush @{[int @keys]} conversations...");
    $redis->$flush;
  },
);

$app->log->info("Will flush conversation log before $human");
$app->log->info("Getting list of conversations...");
$redis->ioloop->start;
print "\n";
$app->log->info("Conversation log before $human was flushed");
