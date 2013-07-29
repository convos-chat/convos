package t::Helper;
use strict;
use warnings;
use Test::More;
use Test::Mojo;

BEGIN { $ENV{WIRC_DEBUG} //= $ENV{TEST_VERBOSE} }

my $t;

sub capture_redis_errors {
  my $class = shift;
  $t->app->redis->on(error => sub {
    my ($redis,$error) = @_;
    ok(0, "An error occured: $error");
    exit;
  });
}

sub init_database {
  my $class = shift;
  my $delay
    = Mojo::IOLoop->delay(
      sub {
        $t->app->redis->select(11, $_[0]->begin);
      },
      sub {
        $t->app->redis->flushdb($_[0]->begin);
      },
      sub {
        Test::More::diag('Database initialized');
      }
    );

  $delay->wait;
}

sub redis_do {
  my $delay = Mojo::IOLoop->delay;
  $t->app->redis->execute(@_, $delay->begin);
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
  $ENV{REDIS_TEST_DATABASE} ||= 'redis://127.0.0.1:6379/14';

  # make sure we use our own test database
  $t = Test::Mojo->new('WebIrc');
  $t->app->config(redis => $ENV{REDIS_TEST_DATABASE});
  $t->app->core->redis->server eq $ENV{REDIS_TEST_DATABASE} or die;
  $t->app->redis->server eq $ENV{REDIS_TEST_DATABASE} or die;
  $t->app->redis->flushdb unless $ENV{KEEP_REDIS};

  eval "package $caller; use Test::More; 1" or die $@;
  no strict 'refs';
  *{ "$caller\::t" } = \$t;
  *{ "$caller\::redis_do" } = \&redis_do;
  *{ "$caller\::wait_a_bit" } = \&wait_a_bit;
}

1;
