use t::Helper;

my $control = Mojo::Redis->new(server => $t->app->redis->server);
my $server = $t->app->redis->subscribe('connection:1:to_server');
my($form, $tmp);

$form = {
  login => 'foobar',
  password => 'barbar'
};

$t->post_ok('/login' => form => $form)
  ->status_is('401', 'failed to log in')
  ;

# invalid register is tested in landing-page.t

$form = {
  login => 'fooman',
  email => 'foobar@barbar.com',
  password => ['barbar', 'barbar'],
};
$t->post_ok('/register' => form => $form)
  ->status_is('302', 'first user gets to be admin')
  ->header_like('Location', qr{/settings$}, 'Redirect to settings page')
  ;

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Nordaaker - Chat')
  ->element_exists('form[action="/settings/connection"][method="post"]')
  ->element_exists('input[name="host"][id="host"]')
  ->element_exists('input[name="nick"][id="nick"]')
  ->element_exists('select[name="channels"][id="channels"]')
  ->element_exists('option[value="#wirc"]')
  # ->element_exists('input[name="avatar"][id="avatar"]')
  ->element_exists('a.logout[href="/logout"]')
  ->text_is('button[type="submit"][name="action"][value="save"]', 'Add connection')
  ;

$form = {};
$t->post_ok('/settings/connection', form => $form)
  ->element_exists('div.host.error')
  ->element_exists('div.nick.error')
  ->element_exists('div.channels.error', 'channels are required unless the redirect will fail later on')
  ->element_exists_not('div.avatar.error')
  ->element_exists('input[name="host"][value="irc.perl.org"]')
  ->element_exists('input[name="nick"][value]')
  ->element_exists('select[name="channels"]')
  ;

$form = {
  host => 'freenode',
  nick => 'ice_cool',
  channels => ', #way #cool ,,,',
};
$control->brpop('core:control' => 0, sub { $tmp = pop->[1] });
$t->post_ok('/settings/connection', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page')
  ;

is $tmp, 'start:1', 'start connection';

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Nordaaker - Chat')
  ->element_exists('form[action="/1/settings/edit"][method="post"]')
  ->element_exists('input[name="host"][value="freenode"]')
  ->element_exists('input[name="nick"][value="ice_cool"]')
  ->element_exists('select[name="channels"]')
  ->element_exists('option[value="#cool"][selected="selected"]')
  ->element_exists('option[value="#way"][selected="selected"]')
  ->element_exists('a.confirm.button[href="/1/settings/delete"]')
  ->text_is('button[type="submit"][name="action"][value="save"]', 'Update connection')
  ;

$control->brpop('core:control' => 0, sub { $tmp = pop->[1] });
$form->{host} = 'irc.perl.org';
$t->post_ok('/1/settings/edit', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page')
  ;

is $tmp, 'restart:1', 'restart connection on host change';

$server->once(message => sub { $tmp = $_[1] });
$form->{nick} = 'marcus';
$t->post_ok('/1/settings/edit', form => $form)->status_is('302');
is $tmp, 'NICK marcus', 'NICK marcus';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#way';
$t->post_ok('/1/settings/edit', form => $form)->status_is('302');
is $tmp, 'PART #cool', 'PART #cool';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#wirc';
$t->post_ok('/1/settings/edit', form => $form)->status_is('302');
is $tmp, 'JOIN #wirc', 'JOIN #wirc';

$t->post_ok('/settings/2', form => $form)->status_is('404');
$t->get_ok('/2/settings/delete')->status_is('404');

$control->brpop('core:control' => 0, sub { $tmp = pop->[1] });
$t->get_ok('/1/settings/delete')
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page after delete')
  ;
is $tmp, 'stop:1', 'stop connection';

$t->get_ok('/logout')
  ->status_is(302)
  ->header_like('Location', qr{/$}, 'Logout')
  ;

$t->post_ok('/1/settings/edit', form => $form)
  ->status_is(302)
  ->header_like('Location', qr{/$}, 'Need to login')
  ;

$form = {
    login => 'fooman',
    email => 'foobar@barbar.com',
    password => ['barbar', 'barbar'],
};
$t->post_ok('/' => form => $form)
  ->status_is(400)
  ->element_exists('div.invite.error .help')
  ->text_is('div.invite.error p.help', 'You need a valid invite code to register.')
  ;

done_testing;
