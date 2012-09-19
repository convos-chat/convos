use t::Helper;

$t->app->redis->on(error => sub {
  my ($redis,$error)=@_;
  ok(0,"An error occured:".$error);
  done_testing;
  exit;
});

$t->get_ok('/login')->status_is('200')->element_exists_not('.alert');
diag 'Done with login test';
$t->get_ok('/register')->status_is('200')->element_exists_not('.error');
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

$t->post_form_ok('/register' => { login => '1', password => '1', email => '1' })
  ->status_is('200')
  ->element_exists('.error')
  ->element_exists('div[title*="Username must consist"]')
  ->element_exists('div[title*="Invalid email"]')
  ->element_exists('div[title*="same password twice"]');

$t->post_form_ok('/register' => {
    login => 'foobar',
    email => 'foobar@barbar.com',
    password => ['barbar', 'barbar'],
  })
  ->status_is('302');

$t->ua->cookie_jar->empty; # logout
diag 'same user tries to log in later on...';
$t->post_form_ok('/login' => { login => 'foobar', password => 'barbar' })
  ->status_is('302');

$t->ua->cookie_jar->empty; # logout
diag 'new user tries to log in...';
$t->post_form_ok('/register' => {})
  ->status_is(200, 'Second user needs an invite code')
  ->element_exists('.alert')
  ->content_like(qr{Invalid invite code});

$t->post_form_ok('/register' => {
    login => 'foobar',
    password => ['barbar', 'barbar'],
    email => 'marcus@iusethis.com',
    secret => crypt('marcus@iusethis.com'.$t->app->secret, rand 1000),
  })
  ->status_is('200')
  ->element_exists('.error')
  ->element_exists('div[title*="Username is taken"]')
  ;

$t->post_form_ok('/register' => {
    login => 'number2',
    password => ['barbar', 'barbar'],
    email => 'marcus@iusethis.com',
    secret => crypt('marcus@iusethis.com'.$t->app->secret, rand 1000),
  })
  ->status_is('302');

done_testing;
