use t::Helper;

my $version;
no warnings 'redefine';
*Mojo::Redis::info = sub {
  my($redis, $what, $cb) = @_;
  $redis->$cb("redis_version:$version");
};

$version = '2.4.9';
$t->get_ok('/login')
  ->status_is(200)
  ->element_exists('div.row.question')
  ->content_like(qr{The Redis server is too old})
  ;

delete $t->app->config->{redis_version};
$version = 'x7';
$t->get_ok('/login')
  ->status_is(200)
  ->element_exists('div.row.question')
  ->content_like(qr{The Redis server is too old})
  ;

delete $t->app->config->{redis_version};
$version = '2.6.13';
$t->get_ok('/login')
  ->status_is(200)
  ->element_exists_not('div.row.question')
  ;

done_testing;
