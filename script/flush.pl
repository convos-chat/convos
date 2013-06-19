#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use WebIrc;
my $now=time;
my $yesterday = $now -86400;

# Start commands for application
my $app=WebIrc->new();
warn ref $app->redis;
$app->redis->execute('keys','connection:*:msg',sub {
  my($redis,$keys)=@_;
  for my $key (@$keys) {
    $redis->zremrangebyscore($key => '-inf','('.$yesterday);
  };
  $redis->keys('*:msg',sub {
    $redis->ioloop->stop;
    });
  });

  $app->redis->ioloop->start;