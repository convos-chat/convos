use t::Helper;

my $server = $t->app->redis->subscribe('convos:user:fooman:magnet');
my ($form, $tmp, @ctrl);

$t->app->core->start;

{
  no warnings 'redefine';
  *Convos::Core::ctrl_start = sub { shift; push @ctrl, @_ };
}

$form = {login => 'foobar', password => 'barbar'};

$t->post_ok('/login' => form => $form)->status_is('401', 'failed to log in');

# invalid register is tested in landing-page.t

$form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar',};
$t->post_ok('/register' => form => $form)->status_is('302', 'first user gets to be admin')
  ->header_is('Location', '/wizard', 'Redirect to settings page');

$t->get_ok($t->tx->res->headers->location)->status_is(200)->text_is('title', 'Testing - Add connection')
  ->element_exists('form[action="/connection/add"][method="post"]')->element_exists('select[name="name"]')
  ->element_exists('select[name="name"] option[value="efnet"]')->element_exists('input[name="nick"][id="nick"]')
  ->element_exists('input[name="channels"][id="channels"][value="#convos"]')
  ->element_exists('input[type="hidden"][name="wizard"][value="1"]')->text_is('form button', 'Start chatting');

$form = {wizard => 1};
$t->post_ok('/connection/add', form => $form)->status_is(200)->element_exists('div.name > .error')
  ->element_exists_not('div.avatar > .error')->element_exists('select[name="name"] option[value="magnet"]')
  ->element_exists('input[name="nick"][value]')->element_exists('input[name="channels"]')
  ->element_exists('input[type="hidden"][name="wizard"][value="1"]');

$form = {wizard => 1, name => 'freenode', nick => 'ice_cool', channels => ', #way #cool ,,,',};
$t->post_ok('/connection/add', form => $form)->status_is('302')
  ->header_is('Location', '/convos', 'Redirect back to settings page');

is_deeply \@ctrl, [qw( fooman freenode )], 'start connection';

$t->get_ok($t->tx->res->headers->location)->status_is(200)->text_is('title', 'Testing - convos')
  ->element_exists('div.messages ul li')->element_exists('div.messages ul li:first-child img[src^="/avatar"]')
  ->text_is('div.messages ul li:first-child h3 a',        'convos')
  ->text_is('div.messages ul li:first-child div.content', 'Hi fooman!');

$t->get_ok('/profile')->status_is(200)->element_exists('form input[name="email"][value="foobar@barbar.com"]')
  ->element_exists('form input[name="avatar"][value="foobar@barbar.com"]');


done_testing;
