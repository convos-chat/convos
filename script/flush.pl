#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use WebIrc;

# Start commands for application
my $app=WebIrc->new();
warn ref $app->redis;
$app->redis->execute('keys','*:msg',sub {
  my($redis,$keys)=@_;
  for my $key (@$keys) {
    $redis->del($key);
  };
  $redis->keys('*:msg',sub {
    $redis->ioloop->stop;
    });
  });

  $app->redis->ioloop->start;