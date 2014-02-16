BEGIN { $ENV{CONVOS_SKIP_VERSION_CHECK} = 1 }
use t::Helper;
use Convos::Core;

my $core = $t->app->core;
my $sub  = $core->redis->subscribe('convos:user:doe:out');
my $stop = sub {1};
my ($connection, @messages, @irc_write);

redis_do(
  [sadd  => 'connections',          'doe:magnet'],
  [hmset => 'user:doe',             digest => 'E2G3goEIb8gpw', email => ''],
  [sadd  => 'user:doe:connections', 'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

{
  $sub->on(
    message => sub {
      my ($sub, $message, $channel) = @_;
      push @messages, $message;
      local $_ = $message;
      Mojo::IOLoop->stop if $stop->();
    }
  );

  no warnings 'redefine';
  *Mojo::IRC::connect = sub { Mojo::IOLoop->stop; };
  *Mojo::IRC::write = sub { shift; push @irc_write, join ' ', @_; };
  $core->start(sub { });
  Mojo::IOLoop->start;

  ok $connection = $core->{connections}{doe}{magnet}, 'got connection';
}

{
  @irc_write = ();
  $connection->irc_join({prefix => 'doe!user@host', params => ['#convos']});
  Mojo::IOLoop->start;
  is_deeply \@irc_write, ['TOPIC #convos'], 'TOPIC #convos on irc_join';
  is redis_do(hget => 'user:doe:connection:magnet:#convos', 'topic'), '', 'no topic for #convos';
}

{
  @irc_write = ();
  $connection->irc_topic({params => ['#convos', 'Super cool topic']});
  Mojo::IOLoop->start;
  is redis_do(hget => 'user:doe:connection:magnet:#convos', 'topic'), 'Super cool topic', 'got topic for #convos';
}

{
  @irc_write = ();
  $connection->irc_rpl_topic({params => ['...', '#convos', 'Super duper cool topic']});
  Mojo::IOLoop->start;
  is redis_do(hget => 'user:doe:connection:magnet:#convos', 'topic'), 'Super duper cool topic', 'got topic for #convos';
}

done_testing;
