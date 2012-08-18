use Test::More;

use Test::Mojo;

my $t=Test::Mojo->new('WebIrc');

$t->app->redis->on(error => sub {
  ok(0,"Oops:".$redis->error);
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
$t->post_form_ok('/login' => { login => 'foo', password => 'bar' })
  ->status_is('200')
  ->element_exists('.alert');

done_testing;
