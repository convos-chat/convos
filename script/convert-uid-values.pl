#!/usr/bin/perl
use feature 'say';
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WebIrc;

my $app = WebIrc->new;
my $redis = $app->redis;
my $delay = Mojo::IOLoop->delay;

$delay->steps(
  sub {
    my($delay) = @_;
    say "del connections";
    $redis->keys('user:*:connections' => $delay->begin);
  },
  sub {
    my($delay, $keys) = @_;


    for my $key (@$keys) {
      $delay->begin(0)->($key);
      $redis->smembers($key, $delay->begin);
    }
  },
  sub {
    my $delay = shift;
    my %hosts;

    while(@_) {
      my($key, $hosts) = (shift, shift);
      my $login = $key =~ /user:(\w+):/ ? $1 : 'UNKNOWN';
      my @connections = join ' ', map { "$login:$_" } @$hosts;
      say "sadd connections @connections";
    }

    $app->log->debug("Done!");
  }
);

$delay->wait;
exit 0;
