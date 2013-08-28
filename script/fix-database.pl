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

    say "del connections";

    for my $uid (1..$max_uid) {
      say "del user:$uid:connections";
      if(my $cids = shift @res) { # maybe a user is deleted?
        for my $cid (@$cids) {
          $delay->begin(0)->($uid, $cid);
          $redis->hget("connection:$cid", 'host', $delay->begin);
        }
      }
    }
  },
  sub {
    my $delay = shift;
    my %hosts;

    while(@_) {
      my($uid, $cid, $host) = (shift, shift, shift);
      push @{ $hosts{$uid} }, $host;
      say "rename connection:$cid uid:$uid:connection:$host";
      say "sadd connections $uid:$host";
      $delay->begin(0)->($uid, $host);
      $redis->smembers("connection:$cid:channels", $delay->begin);
      $redis->keys("connection:$cid:*", $delay->begin);
    }

    while(my($uid, $hosts) = each %hosts) {
      say "sadd user:$uid:connections @$hosts";
    }
  },
  sub {
    my $delay = shift;

    while(@_) {
      my($uid, $host, $channels, $keys) = (shift, shift, shift, shift);
      for my $key (@$keys) {
        my($rest) = $key =~ /connection:\d+:(.+)/ ? $1 : 'WHAT';
        say "hset uid:$uid:connection:$host channels @$channels" if ref $channels;
        if($key =~ /:(?:nicks|unread|channels)$/) {
          say "delete $key";
        }
        else {
          say "rename $key uid:$uid:connection:$host:$rest";
        }
      }
    }

    $app->log->debug("Done!");
  }
);

$delay->wait;
exit 0;
