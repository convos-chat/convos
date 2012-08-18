use Test::More;

use Test::Mojo;

my $t=Test::Mojo->new('WebIrc');

$t->get_ok('/login')->status_is('200')->element_exists_not('alert');
$t->get_ok('/register')->status_is('200')->element_exists_not('alert');

my $delay=Mojo::IOLoop->delay(sub {
  my $delay=shift;
  warn('IMA GONNA '.$t->app->redis);
  $t->app->redis->select(11,$delay->begin);
}, sub {
  my $delay=shift;
  warn "NEVER GOT HERE";
  $t->app->redis->flushdb;
  $t->post_form_ok('/login' => { login => 'foo', password => 'bar' })
  ->status_ok('200')
  ->element_exists('alert');
},sub {
  done_testing;
});
