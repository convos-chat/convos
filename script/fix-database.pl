#!/usr/bin/perl
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
    $redis->get('user:uids' => $delay->begin);
  },
  sub {
    my($delay, $max_uid) = @_;

    $delay->begin(0)->($max_uid);

    for my $uid (1..$max_uid) {
      $redis->smembers("user:$uid:connections", $delay->begin);
    }
  },
  sub {
    my($delay, $max_uid, @res) = @_;

    for my $uid (1..$max_uid) {
      my $cids = shift @res or next; # maybe a user is deleted?
      $app->log->info("Adding uid=$uid to cid=@$cids");
      for my $cid (@$cids) {
        $redis->hset("connection:$cid", uid => $uid, $delay->begin);
      }
    }
  },
  sub {
    my($delay, @res) = @_;
    $app->log->info("Done!");
  }
);

$delay->wait;
exit 0;
