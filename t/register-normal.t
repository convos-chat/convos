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

$ENV{CONVOS_DEFAULT_CONNECTION} = 'irc.perl.org:7062';
$t->get_ok('/wizard')->status_is(200)->text_is('title', 'Nordaaker - Add connection')
  ->element_exists('form[action="/connection/add"][method="post"]')
  ->element_exists('input[name="nick"][id="nick"][value="fooman"]')
  ->element_exists('input[name="server"][id="server"][value="irc.perl.org:7062"]')
  ->element_exists('input[type="hidden"][name="wizard"][value="1"]')->text_is('form button', 'Connect');

$form = {wizard => 1, server => '', nick => ''};
$t->post_ok('/connection/add', form => $form)->status_is(200)->element_exists('div.nick > .error')
  ->element_exists('div.server > .error')->element_exists('input[type="hidden"][name="wizard"][value="1"]');

$form = {wizard => 1, server => 'irc.perl.org:7062', nick => 'ice_cool'};
$t->post_ok('/connection/add', form => $form)->status_is('302')
  ->header_is('Location', '/magnet', 'Redirect to connection page');

is_deeply \@ctrl, [qw( fooman magnet )], 'start connection';

$t->get_ok($t->tx->res->headers->location)->status_is(200)->text_is('title', 'Nordaaker - magnet')
  ->element_exists('div.messages ul li')->text_is('div.messages ul li:first-child h3 a', 'convos');

$t->get_ok('/convos')->status_is(200)->text_is('title', 'Nordaaker - magnet')->element_exists('div.messages ul li')
  ->element_exists('div.messages ul li:first-child .avatar');

$t->get_ok('/profile')->status_is(200)->element_exists('form input[name="email"][value="foobar@barbar.com"]')
  ->element_exists('form input[name="avatar"][value="foobar@barbar.com"]');

done_testing;
