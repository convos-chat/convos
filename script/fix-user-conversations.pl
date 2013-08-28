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
      $redis->zrange("user:$uid:conversations", 0, -1, $delay->begin);
    }
  },
  sub {
    my($delay, $max_uid, @res) = @_;
    my @rem;

    say "del connections";

    for my $uid (1..$max_uid) {
      my $conversations = shift @res or next; # maybe a user is deleted?
      for(@$conversations) {
        push @rem, $_ if /^\d+:00:/ or !$_;
      }
      if(@rem) {
        local $" = '" "';
        say qq(zrem user:$uid:conversations "@rem");
      }
    }

    $app->log->debug("Done!");
  }
);

$delay->wait;
exit 0;
