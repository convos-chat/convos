use t::Helper;

t::Helper->capture_redis_errors($t);
t::Helper->init_database($t);

# normal index page
$t->get_ok('/', 'index page')
  ->status_is('200')
  ->element_exists('a[href="/login"]')
  ->element_exists('a[href="/register"]')
  ;

async_do(sub {
  $t->app->core->add_connection(1 => {
    host => 'localhost',
    nick => 'fooman',
    user => 'fooname',
    channels => '#yikes',
  }, $_[0]->begin);
});

# create account
$t->post_ok('/register' => form => {
    login => 'foobar',
    email => 'foobar@barbar.com',
    password => ['barbar', 'barbar'],
  })
  ->status_is('302');

# index page after login
$t->get_ok('/')
  ->status_is('302')
  ->header_like('Location', qr{/1/%23yikes}, 'Redirect to index page')
  ;

$t->get_ok('/2/foo')
  ->status_is('302')
  ->header_like('Location', qr{/1/%23yikes}, 'Redirect on invalid conversation')
  ;

$t->get_ok('/1/%23yikes')
  ->status_is(200, 'Render yikes conversation')
  ->element_exists('.conversation-list')
  ->element_exists('#target_1')
  ->element_exists('#target_1_yikes')
  ->element_exists('#conversation')
  ->element_exists('#chat-messages[data-cid="1"][data-target="#yikes"]')
  ->element_exists('.chat-input')
  ;

done_testing;
