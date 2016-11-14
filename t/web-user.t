use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND}     = 'Convos::Core::Backend';
$ENV{CONVOS_INVITE_CODE} = '';
my $t = t::Helper->t;

# Will always render the landing page
$t->get_ok('/')->status_is(200)->text_is('title', 'Convos for Nordaaker')
  ->element_exists('link[rel="stylesheet"]')->element_exists('#loader')
  ->element_exists('#vue_tooltip')->element_exists('script')
  ->text_like('script', qr{apiUrl:\s*"/api"}m,          'apiUrl')
  ->text_like('script', qr{wsUrl:\s*"ws://.*/events"}m, 'wsUrl')
  ->text_like('script', qr{"invite_code":\s*false}m,    'invite_code');

my $viewport = $t->tx->res->dom->at('meta[name="viewport"]')->{content};
like $viewport, qr{width=device-width}, 'viewport width';
like $viewport, qr{initial-scale=1},    'viewport initial-scale';
like $viewport, qr{maximum-scale=1},    'viewport maximum-scale';

$t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->delete_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->post_ok('/api/user', json => {})->status_is(401)
  ->json_is('/errors/0/message', 'Need to log in first.')->json_is('/errors/0/path', '/');

$t->post_ok('/api/user/register', json => {email => 'superman', password => 'xyz'})->status_is(400)
  ->json_is('/errors/0', {message => 'Does not match email format.', path => '/body/email'});

$t->post_ok('/api/user/register', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200)->json_is('/email', 'superman@example.com')
  ->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
my $registered = $t->tx->res->json->{registered};

$t->post_ok('/api/user', json => {})->status_is(200);

$t->get_ok('/api/user')->status_is(200)
  ->json_is('', {email => 'superman@example.com', registered => $registered, unread => 0});

$t->app->core->get_user('superman@example.com')->unread(4);
$t->get_ok('/api/user?connections=true&dialogs=true&notifications=true')->status_is(200)->json_is(
  '',
  {
    connections   => [],
    dialogs       => [],
    notifications => [],
    email         => 'superman@example.com',
    registered    => $registered,
    unread        => 4,
  }
);

$t->post_ok('/api/notifications/read')->status_is(200);

$t->delete_ok('/api/user')->status_is(400)
  ->json_is('/errors/0/message', 'You are the only user left.');

$t->get_ok('/api/user/logout')->status_is(302);
$t->get_ok('/api/user')->status_is(401);

done_testing;
