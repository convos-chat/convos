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
my $app           = Convos->new;
my ($flush, @keys);

$flush = sub {
  my $redis = shift;
  my $key = shift @keys or return $redis->ioloop->stop;

  $redis->zremrangebyscore($key => "-inf", "($remove_before", $flush);
};

$app->redis->execute(
  'keys',
  'connection:*:msg',
  sub {
    my ($redis, $keys) = @_;
    @keys = @$keys;
    $app->log->info("Will flush @{[int @keys]} conversations...\n");
    $redis->$flush;
  },
);

$app->log->info("Will flush conversation log before @{[localtime $remove_before]}");
$app->log->info("Getting list of conversations...");
$app->redis->ioloop->start;
$app->log->info("Conversation log before @{[localtime $remove_before]} was flushed");
