#!perl
use lib '.';
use t::Selenium;

$ENV{CONVOS_INVITE_CODE}    = '';
$ENV{CONVOS_DEFAULT_SERVER} = 'localhost';

my $t = t::Selenium->selenium_init;

$t->wait_for('.convos-login');
$t->click_ok('[href="#page:register"]');

# Without invite code
$t->wait_for('.convos-register');
$t->send_keys_ok('#form_login_email',          [t::Selenium->email, \'tab']);
$t->send_keys_ok('#form_login_password',       ['secret',           \'tab']);
$t->send_keys_ok('#form_login_password_again', ['secret',           \'enter']);

$t->wait_for('.convos-settings');
$t->send_keys_ok('.convos-connection-settings [name="server"]', [(\'backspace') x 30]);
$t->send_keys_ok('.convos-connection-settings [name="server"]', ['dummy.convos.by:6668', \'enter']);

$t->wait_for('.convos-create-dialog');

my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-dummy-convos');
ok $connection, 'created connection with non-standard server name';
like $connection->url->to_unsafe_string, qr{irc://dummy\.convos\.by:6668}, 'non default url';

done_testing;
