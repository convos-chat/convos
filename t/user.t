use Test::More;

use Test::Mojo;

my $t=Test::Mojo->new('WebIrc');

$t->app->redis->on(error => sub {
  ok(0,"Oops:".$t->app->redis->error);
  done_testing;
});

$t->get_ok('/login')->status_is('200')->element_exists_not('.alert');
$t->get_ok('/register')->status_is('200')->element_exists_not('.alert');

my $delay=Mojo::IOLoop->delay(sub {
  my $delay=shift;
  $t->app->redis->select(11,$delay->begin);
}, sub {
  my $delay=shift;
  $t->app->redis->flushdb($delay->begin);
},sub {
  my $delay=shift;
});
$delay->wait;
$t->post_form_ok('/login' => { login => 'foobar', password => 'barbar' })
  ->status_is('200')
  ->element_exists('.alert');
$t->post_form_ok('/register' => { login => 'foobar', password => 'barbar' })
  ->status_is('302');
$t->post_form_ok('/login' => { login => 'foobar', password => 'barbar' })
  ->status_is('302');
$t->post_form_ok('/register' => { login => 'foobar', password => 'barbar', email => 'marcus@iusethis.com',secret =>
   crypt('marcus@iusethis.com'.$t->app->secret,1) })
  ->status_is('200')
  ->element_exists('.alert');
$t->post_form_ok('/register' => { login => 'barbar', password => 'barbar' })
  ->status_is('404', 'Second user needs an invite code');

done_testing;
