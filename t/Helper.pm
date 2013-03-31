package t::Helper;
use strict;
use warnings;
use Test::More;
use Test::Mojo;

BEGIN { $ENV{WIRC_DEBUG} = 1 }

sub capture_redis_errors {
  my($class, $t) = @_;
  $t->app->redis->on(error => sub {
    my ($redis,$error) = @_;
    ok(0, "An error occured: $error");
    exit;
  });
}

sub init_database {
  my($class, $t) = @_;
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

sub async_do {
  my $delay = Mojo::IOLoop->delay;
  $_->($delay) for @_;
  $delay->wait;
}

sub redis_do {
  my $t = shift;
  my $delay = Mojo::IOLoop->delay;

  while(@_) {
    my $method = shift;
    my $args = shift;
    $t->app->redis->$method(@$args, $delay->begin);
  }

  $delay->wait;
}

sub import {
  my $class = shift;
  my $caller = caller;
  my $t = Test::Mojo->new('WebIrc');

  strict->import;
  warnings->import;

  # make sure we use our own test database
  $t->app->redis->select($ENV{REDIS_TEST_DB} || 11);
  $t->app->redis->flushdb if $ENV{REDIS_TEST_DB};

  eval "package $caller; use Test::More; 1" or die $@;
  no strict 'refs';
  *{ "$caller\::t" } = \$t;
  *{ "$caller\::async_do" } = \&async_do;
  *{ "$caller\::redis_do" } = \&redis_do;

}

1;
