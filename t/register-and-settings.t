use t::Helper;

t::Helper->capture_redis_errors;
t::Helper->init_database;

my $control = $t->app->redis->subscribe('core:control');
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
  ->text_is('title', 'Nordaaker - Settings')
  ->element_exists('form[action="/settings/add"][method="post"]')
  ->element_exists('input[name="host"][id="host"]')
  ->element_exists('input[name="nick"][id="nick"]')
  ->element_exists('input[name="channels"][id="channels"]')
  ->element_exists('input[name="avatar"][id="avatar"]')
  ->element_exists('a.settings.active[href="/settings"]')
  ->element_exists('a.logout[href="/logout"]')
  ->element_exists_not('a.chat[href="/"]', 'no chat to go to')
  ->text_is('button[type="submit"][name="action"][value="save"]', 'Add')
  ->text_is('button[type="submit"][name="action"][value="connect"]', 'Add & Chat')
  ;

$form = {};
$t->post_ok('/settings/add', form => $form)
  ->element_exists('div.host.error')
  ->element_exists('div.nick.error')
  ->element_exists('div.channels.error', 'channels are required unless the redirect will fail later on')
  ->element_exists_not('div.avatar.error')
  ->element_exists('input[name="host"][value="irc.perl.org"]')
  ->element_exists('input[name="nick"][value]')
  ->element_exists('input[name="channels"][value="#wirc"]')
  ->element_exists('input[name="avatar"][value]')
  ;


$form = {
  host => 'freenode',
  nick => 'ice_cool',
  channels => ', #way #cool ,,,',
};
$control->once(message => sub { $tmp = $_[1] });
$t->post_ok('/settings/add', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings/1$}, 'Redirect back to settings page')
  ;
is $tmp, 'start:1', 'start connection';

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Nordaaker - Settings')
  ->element_exists('form[action="/settings/1"][method="post"]')
  ->element_exists('input[name="host"][value="freenode"]')
  ->element_exists('input[name="nick"][value="ice_cool"]')
  ->element_exists('input[name="channels"][value="#cool #way"]')
  ->element_exists('input[name="avatar"][value]')
  ->element_exists('a.chat[href="/"]', 'go to chat')
  ->text_is('button[type="submit"][name="action"][value="save"]', 'Save')
  ->text_is('button[type="submit"][name="action"][value="connect"]', 'Save & Chat')
  ->text_is('button[type="submit"][name="action"][value="delete"][class="confirm"]', 'Delete')
  ;

$tmp = undef;
$control->once(message => sub { $tmp = $_[1] });
$server->once(message => sub { $tmp = $_[1] });
$form->{action} = 'connect';
$t->post_ok('/settings/1', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/$}, 'Redirect to index page on action=connect')
  ;

is $tmp, undef, 'nothing publish, since nothing changed';

delete $form->{action};
$form->{host} = 'irc.perl.org';
$t->post_ok('/settings/1', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page')
  ;

is $tmp, 'restart:1', 'restart connection on host change';

$form->{nick} = 'marcus';
$t->post_ok('/settings/1', form => $form)->status_is('302');
is $tmp, 'NICK marcus', 'NICK marcus';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#way';
$t->post_ok('/settings/1', form => $form)->status_is('302');
is $tmp, 'PART #cool', 'PART #cool';

$server->once(message => sub { $tmp = $_[1] });
$form->{channels} = '#wirc';
$t->post_ok('/settings/1', form => $form)->status_is('302');
is $tmp, 'JOIN #wirc', 'JOIN #wirc';

$t->post_ok('/settings/2', form => $form)->status_is('404');

$form->{action} = 'delete';
$t->post_ok('/settings/2', form => $form)->status_is('404');

$tmp = undef;
$control->once(message => sub { $tmp = $_[1] });
$t->post_ok('/settings/1', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page after delete')
  ;
is $tmp, 'stop:1', 'stop connection';

$t->get_ok('/logout')
  ->status_is(302)
  ->header_like('Location', qr{/$}, 'Logout')
  ;

$t->post_ok('/settings/1', form => $form)
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
