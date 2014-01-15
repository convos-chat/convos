use t::Helper;
use Convos::Core;

my $core  = $t->app->core;
my $redis = $t->app->redis;

{
  my $delay = Mojo::IOLoop->delay;
  my @cb = ($delay->begin(0), $delay->begin(0));

  is $core->redis->server, $redis->server, 'core use the right redis server';

  $core->control(
    foo => 'bar',
    sub {
      pop(@cb)->('a');
    }
  );
  $redis->brpop(
    'core:control',
    1,
    sub {
      pop(@cb)->($_[1]->[1]);
    }
  );

  is_deeply [sort $delay->wait], ['a', 'foo:bar'], 'pushed foo:bar to control';
}

{
  is_deeply(
    [$core->_parse_channels(['#foo', '#bar #baz ,,, stuff', '  #foo'])],
    ['#bar', '#baz', '#foo', '#stuff'],
    '_parse_channels()',
  );
}

{
  my $delay    = Mojo::IOLoop->delay;
  my @cb       = ($delay->begin(0));
  my $upgraded = 0;

  is $core->start, $core, 'start()';

  is $core->{control}->server, $redis->server, 'core control use the right redis server';
  $core->control(foo => 'bar', sub { });
  $core->{control}->once(
    error => sub {
      pop(@cb)->($_[1]);
    }
  );

  like $delay->wait, qr{locate object method "ctrl_foo"}, 'invalid control method';

  $delay = Mojo::IOLoop->delay;
  @cb    = ($delay->begin(0));
  local *Convos::Core::ctrl_foo = sub { pop(@cb)->(@_) };
  isa_ok(\&Convos::Core::ctrl_foo, 'CODE');
  $core->control(foo => 'doe', 'magnet', sub { });
  is_deeply [$delay->wait], [$core, 'doe', 'magnet'], 'ctrl_foo()';
}

done_testing;
