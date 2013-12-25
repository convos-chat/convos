package t::Helper;
use strict;
use warnings;
use Test::More;
use Test::Mojo;

BEGIN {
  $ENV{MOJO_MODE} = 'testing';
  $ENV{CONVOS_DEBUG} //= $ENV{TEST_VERBOSE};
  $ENV{REDIS_TEST_DATABASE} ||= '';
}

my $t;

sub redis_do {
  my $delay = Mojo::IOLoop->delay;
  my $redis = $t->app->redis;
  $redis->execute(@_, $delay->begin);
  $delay->wait;
}

sub wait_a_bit {
  my($cb, $text) = @_;
  my $tid = Mojo::IOLoop->timer(2, sub {
    Test::More::ok(0, $text || 'TIMED OUT!');
    Mojo::IOLoop->stop;
  });
  return sub {
    Mojo::IOLoop->remove($tid);
    $cb->();
    Mojo::IOLoop->stop;
  };
}

sub import {
  my $class = shift;
  my $caller = caller;
  my $keys;

  strict->import;
  warnings->import;
  $ENV{REDIS_TEST_DATABASE} = 'redis://127.0.0.1:6379/14' if $ENV{REDIS_TEST_DATABASE} eq 'default';

  # make sure we use our own test database
  $t = Test::Mojo->new('Convos');
  $t->app->config(redis => $ENV{REDIS_TEST_DATABASE});
  $t->app->core->redis->server eq $ENV{REDIS_TEST_DATABASE} or die;
  $t->app->redis->server eq $ENV{REDIS_TEST_DATABASE} or die;

  redis_do('flushdb') unless $ENV{KEEP_REDIS};

  eval "package $caller; use Test::More; 1" or die $@;
  no strict 'refs';
  *{ "$caller\::t" } = \$t;
  *{ "$caller\::redis_do" } = \&redis_do;
  *{ "$caller\::wait_a_bit" } = \&wait_a_bit;
}

1;
