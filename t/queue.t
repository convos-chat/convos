use Mojo::Base -strict;
use Test::More;
use Convos::Util::Queue;
use Time::HiRes qw(time);

my $q = Convos::Util::Queue->new(delay => 0.3);

subtest initial => sub {
  is $q->size('i1'), 0, 'nothing in queue';
};

subtest enqueue => sub {
  my $p = $q->enqueue_p(e1 => sub { Mojo::Promise->resolve });
  is $q->size('e1'), 1, 'size = pending + queued';

  my $done;
  $p->then(sub { $done = 1 })->wait;
  is $done, 1, 'resolved';
};

subtest multiple => sub {
  my (@p, @res);
  push @p, $q->enqueue_p(m1 => sub { push @res, ['b', $q->size('m1'), time] });
  push @p, $q->enqueue_p(m1 => sub { push @res, ['c', $q->size('m1'), time] });

  is $q->size('m1'), 2, 'size = pending + queued';

  push @res, [a => $q->size('m1'), time];
  Mojo::Promise->all(@p)->wait;
  is $q->size('m1'), 0, 'done';

  my $t0   = $res[0][2];
  my @time = map { my $t = pop @$_; int 1000 * ($t - $t0) } @res;
  is_deeply \@res, [[a => 2], [b => 2], [c => 1]], 'res';
  ok $time[1] - $time[0] < 10,   "time @time";
  ok $time[2] - $time[1] >= 300, "time @time";
};

subtest parallel => sub {
  my (@p, @res);
  push @p, $q->enqueue_p(foo => sub { push @res, [foo => $q->size('foo'), time] });
  push @p, $q->enqueue_p(bar => sub { push @res, [bar => $q->size('bar'), time] });
  push @p, $q->enqueue_p(baz => sub { push @res, [baz => $q->size('baz'), time] });

  my $t0 = time;
  Mojo::Promise->all(@p)->wait;
  my @time = map { pop @$_ } @res;
  is_deeply \@res, [[foo => 1], [bar => 1], [baz => 1]], 'res';
  ok($_ - $t0 < 0.1, 'time') for @time;
};

subtest reject => sub {
  my (@p, @res);

  $q->delay(2);    # Will be ignored on reject
  push @p, $q->enqueue_p(r1 => sub { Mojo::Promise->reject });
  push @p, $q->enqueue_p(r1 => sub { Mojo::Promise->reject });
  push @p, $q->enqueue_p(r1 => sub { Mojo::Promise->reject });

  is $q->size('r1'), 3, 'size = pending + queued';

  my $t0 = time;
  Mojo::Promise->all(@p)->wait;
  ok + (time - $t0) < 0.5, 'rejected promises does not wait for delay';
};


done_testing;
