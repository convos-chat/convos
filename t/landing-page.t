use t::Helper;

$t->get_ok('/')
  ->status_is(200)
  ->text_is('title', 'Nordaaker - Chat with your friends and colleagues')
  ->element_exists('div.landing-page', 'landing page')
  ->element_exists('a.button[data-toggle="div.login"][href="/login"]')
  ->element_exists('div.login.ignore-document-close form', 'login form which does not close on doc click')
  ->element_exists('a.button[data-toggle="div.register"][href="/register"]')
  ->element_exists('div.register.ignore-document-close form', 'register form which does not close on doc click')
  ->element_exists('a[href="mailto:marcus@nordaaker.no"]', 'contact link')
  ->content_like(qr{<!--\[if IE\]>}, 'with ie warning');
  ;

$t->get_ok('/login')
  ->element_exists('input[name="login"][id="login"]')
  ->element_exists('input[type="password"][name="password"][id="password"]')
  ;

for my $p ('/', '/login') {
  $t->post_ok($p, form => { login => 'whatever' })
    ->status_is(401)
    ->element_exists('div.landing-page', 'still on landing page')
    ->element_exists('a.button.focus.active[data-toggle="div.login"]', 'with login form in focus')
    ->element_exists('a.button[data-toggle="div.register"]')
    ->text_is('.login button[type="submit"]', 'Login')
    ->text_is('div.alert', 'Invalid username/password.')
    ;
}

$t->get_ok('/register')
  ->element_exists('.register input[name="login"][id="register_login"]', 'need custom id to make label target correct element')
  ->element_exists('.register input[name="email"][id="email"]')
  ->element_exists('.register input[name="invite"][id="invite"]')
  ->element_exists('.register input[type="password"][name="password"][id="register_password"]', 'need custom id to make label target correct element')
  ;

for my $p ('/', '/register') {
  $t->post_ok($p, form => { email => 'whatever' })
    ->status_is(400)
    ->element_exists('div.landing-page', 'still on landing page')
    ->element_exists('a.button.focus.active[data-toggle="div.register"]', 'with register form in focus')
    ->element_exists('a.button[data-toggle="div.login"]')
    ->text_is('.register button[type="submit"]', 'Register')
    ->element_exists('div.error.login')
    ->element_exists('div.error.email')
    ->element_exists('div.error.password')
    ;
}

done_testing;
