package t::Helper;
use strict;
use warnings;
use Test::More ();
use Test::Mojo ();


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
}

1;
