#!perl
use lib '.';
use t::Selenium;

$ENV{CONVOS_INVITE_CODE}       = '';
$ENV{CONVOS_BACKEND}           = 'Convos::Core::Backend';
$ENV{CONVOS_FORCED_IRC_SERVER} = 'irc://:secret@chat.example.com:1234';

my $t = t::Selenium->selenium_init;

is $t->app->config->{forced_irc_server}->password, 'secret', 'forced_irc_server password';

$t->wait_for('.convos-login');
$t->click_ok('[href="#page:register"]');

# Without invite code
$t->wait_for('.convos-register');
$t->send_keys_ok('#form_login_email',          [t::Selenium->email, \'tab']);
$t->send_keys_ok('#form_login_password',       ['secret',           \'tab']);
$t->send_keys_ok('#form_login_password_again', ['secret',           \'enter']);

$t->wait_for('.convos-settings');
$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');
$t->live_element_exists('.convos-connection-settings [name="server"][readonly]');
$t->live_element_exists('.convos-connection-settings [type="password"][readonly]');
$t->t::Selenium::form_is(
  '.convos-connection-settings input, .convos-connection-settings textarea',
  ['chat.example.com:1234', $NICK, 'on', '', '', ''],
);

$t->click_ok('.convos-connection-settings [type="submit"]');
$t->wait_for('.convos-create-dialog');

my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-example');
ok $connection, 'created connection with forced server name';
is $connection->url->userinfo, ':secret', 'forced url userinfo'
  or diag $connection->url->to_unsafe_string;
cmp_deeply $connection->url->query->to_hash(1), {forced => 1, nick => $NICK, tls => 0},
  'forced url params';

$t->refresh;
$t->wait_for('.convos-settings');
$t->click_ok('a[href^="#chat/irc-example/"]');
$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');
$t->live_element_exists('.convos-connection-settings [name="server"][readonly]');
$t->live_element_exists('.convos-connection-settings [type="password"][readonly]');
$t->t::Selenium::form_is(
  '.convos-connection-settings input, .convos-connection-settings textarea',
  ['chat.example.com:1234', 'Connected', $NICK, 'off', 'on', '', '', ''],
);

done_testing;
