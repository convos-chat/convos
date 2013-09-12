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
    $redis->keys('user:*uid' => $delay->begin);
  },
  sub {
    my($delay, $keys) = @_;

    for my $key (@$keys) {
      $delay->begin(0)->($key);
      $redis->get($key, $delay->begin);
    }
  },
  sub {
    my $delay = shift;
    my %hosts;

    while(@_) {
      my($key, $uid) = (shift, shift);
      my $username = $key =~ /user:(\w+):/ ? $1 : 'UNKNOWN';
      $delay->begin(0)->($username);
      $redis->keys("user:$uid:*" => $delay->begin);
      say "del $key";
      say "rename user:$uid user:$username";
      say "sadd users $username";
    }
  },
  sub {
    my $delay = shift;

    while(@_) {
      my($username, $keys) = (shift, shift);
      for my $key (@$keys) {
        my $postfix = $key =~ /user:\d+:(.*)/ ? $1 : 'UNKNOWN';
        say "rename $key user:$username:$postfix";
      }
    }

    $app->log->debug("Done!");
  }
);

$delay->wait;
exit 0;
