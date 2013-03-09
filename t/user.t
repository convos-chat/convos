use t::Helper;
BEGIN { $ENV{SKIP_CONNECT}=1; };
$t->app->redis->on(error => sub {
  my ($redis,$error)=@_;
  ok(0,"An error occured:".$error);
  done_testing;
  exit;
});

$t->get_ok('/login')->status_is('200')->element_exists_not('.alert');
# 'Done with login test';
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
$t->post_ok('/login', form => { login => 'foobar', password => 'barbar' })
  ->status_is('200')
  ->element_exists('.alert');

$t->post_ok('/register', form => { login => '1', password => '1', email => '1' })
  ->status_is('200')
  ->element_exists('.error')
  ->element_exists('div[title*="Username must consist"]')
  ->element_exists('div[title*="Invalid email"]')
  ->element_exists('div[title*="same password twice"]');

$t->post_ok('/register', form => {
    login => 'foobar',
    email => 'foobar@barbar.com',
    password => ['barbar', 'barbar'],
  })
  ->status_is('302');

$t->ua->cookie_jar->empty; # logout
# 'same user tries to log in later on...';
$t->post_ok('/login', form => { login => 'foobar', password => 'barbar' })
  ->status_is('302');

$t->ua->cookie_jar->empty; # logout
# 'new user tries to log in...';
$t->post_ok('/register', form=> {})
  ->status_is(200, 'Second user needs an invite code')
  ->element_exists('.error')
  ->content_like(qr{Invalid invite code});

$t->post_ok('/register', form => {
    login => 'foobar',
    password => ['barbar', 'barbar'],
    email => 'marcus@iusethis.com',
    invite=> crypt('marcus@iusethis.com'.$t->app->secret,'marcus@iusethis.com'),
  })
  ->status_is('200')
  ->element_exists('.error')
  ->element_exists('div[title*="Username is taken"]')
  ;
#  diag $t->tx->res->body;

$t->post_ok('/register', form => {
    login => 'number2',
    password => ['barbar', 'barbar'],
    email => 'marcus@iusethis.com',
    invite=> crypt('marcus@iusethis.com'.$t->app->secret, 'marcus@iusethis.com'),
  })
  ->status_is('302');

done_testing;
