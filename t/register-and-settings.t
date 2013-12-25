use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $server = $t->app->redis->subscribe('convos:user:fooman:irc.perl.org');
my ($form, $tmp);

$form = {login => 'foobar', password => 'barbar'};

$t->post_ok('/login' => form => $form)->status_is('401', 'failed to log in');

# invalid register is tested in landing-page.t

$form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar',};
$t->post_ok('/register' => form => $form)
  ->status_is('302', 'first user gets to be admin')
  ->header_like('Location', qr{/wizard$}, 'Redirect to settings page');

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Testing - Add connection')
  ->element_exists('form[action="/settings/connection"][method="post"]')
  ->element_exists('input[name="server"][id="server"]')
  ->element_exists('input[name="nick"][id="nick"]')
  ->element_exists('select[name="channels"][id="channels"]')
  ->element_exists('option[value="#convos"]')
  ->text_is('button[name="action"][value="save"]', 'Start chatting');

$form = { wizard => 1 };
$t->post_ok('/settings/connection', form => $form)
  ->element_exists('div.server > .field-with-error')
  ->element_exists_not('div.avatar > .field-with-error')
  ->element_exists('input[name="server"][value="irc.perl.org"]')
  ->element_exists('input[name="nick"][value]')
  ->element_exists('select[name="channels"]')
  ;

$form = { wizard => 1, server => 'freenode.org', password => 'noway', nick => 'ice_cool', channels => ', #way #cool ,,,',};
$t->post_ok('/settings/connection', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/convos$}, 'Redirect back to settings page');

is redis_do([rpop => 'core:control']), 'start:fooman:freenode.org', 'start connection';

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Testing - Chat')
  ->element_exists('div.messages ul li')
  ->element_exists('div.messages ul li:first-child img[src="/avatar/convos@loopback"]')
  ->text_is('div.messages ul li:first-child h3 a', 'convos')
  ->text_is('div.messages ul li:first-child div', 'Hi fooman!')
  ;

$t->get_ok('/settings')->text_is('title', 'Testing - Chat')
  ->element_exists('form[action="/freenode.org/settings/edit"][method="post"]')
  ->element_exists('input[name="server"][value="freenode.org"]')
  ->element_exists('input[name="password"][value="noway"]')
  ->element_exists('input[name="password"][type="password"]')
  ->element_exists('input[name="nick"][value="ice_cool"]')->element_exists('select[name="channels"]')
  ->element_exists('option[value="#cool"][selected="selected"]')
  ->element_exists('option[value="#way"][selected="selected"]')
  ->element_exists('a.confirm.button[href="/freenode.org/settings/delete"]')
  ->text_is('button[type="submit"][name="action"][value="save"]', 'Update');

$form->{server} = 'irc.perl.org';
$t->post_ok('/freenode.org/settings/edit', form => $form)->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page');

is_deeply(
  [redis_do([rpop => 'core:control'], [rpop => 'core:control'])],
  ['start:fooman:irc.perl.org', 'stop:fooman:freenode.org'],
  'start/stop connection on update',
);

$server->once(message => sub { $tmp = $_[1] });
$form->{nick} = 'marcus';
$t->post_ok('/irc.perl.org/settings/edit', form => $form)->status_is('302');
is $tmp, 'dummy-uuid NICK marcus', 'NICK marcus';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#way';
$t->post_ok('/irc.perl.org/settings/edit', form => $form)->status_is('302');
is $tmp, 'dummy-uuid PART #cool', 'PART #cool';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#convos';
$t->post_ok('/irc.perl.org/settings/edit', form => $form)->status_is('302');
is $tmp, 'dummy-uuid JOIN #convos', 'JOIN #convos';

is_deeply(
  redis_do([hgetall => 'user:fooman:connection:irc.perl.org']),
  {user => 'fooman', server => 'irc.perl.org', nick => 'marcus', tls => 0, login => 'fooman',password=>'noway'},
  'not too much data stored in backend',
);

$t->post_ok('/settings/2', form => $form)->status_is('404');
$t->get_ok('/yay/settings/delete')->status_is('404');

$t->get_ok('/irc.perl.org/settings/delete')->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page after delete');
is redis_do([rpop => 'core:control']), 'stop:fooman:irc.perl.org', 'stop connection';

$t->get_ok('/logout')->status_is(302)->header_like('Location', qr{/$}, 'Logout');

$t->post_ok('/irc.perl.org/settings/edit', form => $form)->status_is(302)
  ->header_like('Location', qr{localhost:\d+/$}, 'Need to login');

$form->{login} = 'fooman';
$t->post_ok('/register' => form => $form)
  ->status_is(400)
  ->text_is('p.error', 'That username is taken.')
  ;

# invite code
$t->app->config->{invite_code}='test';
$t->post_ok('/register' => form => $form)
  ->status_is(400)
  ->text_is('.alert h2', 'Invite only installation.');

done_testing;
