package t::Helper;
use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Mojo::Redis;

BEGIN {
  $ENV{MOJO_MODE} = 'testing';
  $ENV{CONVOS_ARCHIVE_DIR} //= 'irc_logs_test';
  $ENV{CONVOS_DEBUG}       //= $ENV{TEST_VERBOSE};
  $ENV{CONVOS_REDIS_URL}   //= '';
}

my ($redis, $t);

sub redis_do {
  my $delay = Mojo::IOLoop->delay;
  my @res;
  $redis ||= $t->app->redis;
  return $redis unless @_;
  $redis->execute(@_, sub { @res = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  shift @res;
  return wantarray ? @res : $res[0];
}

sub wait_a_bit {
  my ($cb, $text) = @_;
  my $tid = Mojo::IOLoop->timer(
    2,
    sub {
      Test::More::ok(0, $text || 'TIMED OUT!');
      Mojo::IOLoop->stop;
    }
  );
  return sub {
    Mojo::IOLoop->remove($tid);
    $cb->();
    Mojo::IOLoop->stop;
  };
}

sub import {
  my $class  = shift;
  my $caller = caller;
  my $keys;

  strict->import;
  warnings->import;

  if (defined $ENV{LIVE_DATABASE}) {
    $ENV{REDIS_BACKEND_PID} = fork or exec 'redis-server t/etc/redis.conf';
    $ENV{CONVOS_REDIS_URL} = "redis://127.0.0.1:30000/$ENV{LIVE_DATABASE}";
    $ENV{KEEP_REDIS} //= 1;
    sleep 2;    # TODO: Make this more intelligent
  }
  elsif ($ENV{CONVOS_REDIS_URL} eq 'test') {
    $ENV{CONVOS_REDIS_URL} = 'redis://127.0.0.1:6379/14';
  }

  $t = Test::Mojo->new('Convos');

  eval {
    $t->app->core->redis->server eq $ENV{CONVOS_REDIS_URL} or die "invalid core redis server";
    $t->app->redis->server eq $ENV{CONVOS_REDIS_URL} or die "invalid app redis server";
  } or do {
    plan skip_all => $@;
  };

  redis_do('flushdb') unless $ENV{KEEP_REDIS};

  eval "package $caller; use Test::More; 1" or die $@;
  no strict 'refs';
  *{"$caller\::t"}          = \$t;
  *{"$caller\::redis_do"}   = \&redis_do;
  *{"$caller\::wait_a_bit"} = \&wait_a_bit;
}

END {
  kill 15, $ENV{REDIS_BACKEND_PID} and wait if $ENV{REDIS_BACKEND_PID};
}

1;
