use t::Helper;
use Convos::Core;

my $core  = $t->app->core;
my $redis = $t->app->redis;

{
  my @res;

  is $core->redis->server, $redis->server, 'core use the right redis server';

  $core->control(
    foo => 'bar',
    sub {
      push @res, 'a';
      Mojo::IOLoop->stop if @res == 2;
    }
  );
  $redis->brpop(
    'core:control',
    1,
    sub {
      push @res, $_[1]->[1];
      Mojo::IOLoop->stop if @res == 2;
    }
  );

  Mojo::IOLoop->start;
  is_deeply [sort @res], ['a', 'foo:bar'], 'pushed foo:bar to control';
}

{
  is_deeply(
    [$core->_parse_channels(['#foo', '#bar #baz ,,, stuff', '  #foo'])],
    ['#bar', '#baz', '#foo', '#stuff'],
    '_parse_channels()',
  );
}

{
  my $upgraded = 0;
  my @res;

  is $core->start, $core, 'start()';

  is $core->{control}->server, $redis->server, 'core control use the right redis server';
  $core->control(foo => 'bar', sub { });
  $core->{control}->once(
    error => sub {
      push @res, $_[1];
      Mojo::IOLoop->stop;
    }
  );

  Mojo::IOLoop->start;
  like $res[0], qr{locate object method "ctrl_foo"}, 'invalid control method';

  @res = ();
  local *Convos::Core::ctrl_foo = sub { push @res, @_; Mojo::IOLoop->stop; };
  isa_ok(\&Convos::Core::ctrl_foo, 'CODE');
  $core->control(foo => 'doe', 'magnet', sub { });
  Mojo::IOLoop->start;
  is_deeply \@res, [$core, 'doe', 'magnet'], 'ctrl_foo()';
}

done_testing;
