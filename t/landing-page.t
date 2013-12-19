use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

$t->get_ok('/')
  ->status_is(302)
  ->header_like('Location' => qr{:\d+/login$})
  ;

$t->get_ok('/login')
  ->status_is(200)
  ->element_exists('input[name="login"][id="login"]')
  ->element_exists('input[type="password"][name="password"][id="password"]')
  ->content_like(qr{<!--\[if IE\]>}, 'with ie warning')
  ;

$t->post_ok('/login', form => { login => 'whatever', password => 'yikes' })
  ->status_is(401)
  ->element_exists('div.landing-page', 'still on landing page')
  ->text_is('.login button', 'Login')
  ->text_is('p.error', 'Invalid username or password.')
  ;

$t->get_ok('/register')
  ->element_exists('.register input[name="email"][id="email"]')
  ->element_exists('.register input[type="password"][name="password"][id="password"]')
  ;

$t->post_ok('/register', form => { login => 'yikes', email => 'whatever' })
  ->status_is(400)
  ->element_exists('div.landing-page', 'still on landing page')
  ->text_is('.register button', 'Register')
  ->element_exists('p.error');

done_testing;
