use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init;

$t->wait_until(sub { $_->find_element('.convos-login') });
$t->click_ok('[href="#register"]');

$t->wait_until(sub { $_->find_element('.convos-register') });
$t->send_keys_ok('#form_login_email',          [t::Selenium->email,       \'tab']);
$t->send_keys_ok('#form_login_password',       ['secret',                 \'tab']);
$t->send_keys_ok('#form_login_password_again', ['secret',                 \'tab']);
$t->send_keys_ok('#form_login_invite_code',    [$ENV{CONVOS_INVITE_CODE}, \'enter']);

$t->wait_until(sub { $_->find_element('.convos-chat') });
$t->live_element_exists('body.has-sidebar');
$t->live_element_exists('#vue_tooltip');

$t->element_is_displayed('.convos-sidebar-info.is-sidebar');
$t->live_element_exists_not('.convos-notifications.is-sidebar');

$t->element_is_displayed('.convos-main-menu');
$t->live_element_exists('.convos-main-menu .link [href="#connection"]');
$t->live_element_exists('.convos-main-menu .link [href="#profile"]');
$t->live_element_exists('.convos-main-menu .link [href="#help"]');
$t->live_element_exists('.convos-main-menu .link [href$="/logout"]');
$t->live_element_exists('.convos-main-menu .link [href$="#connection"]');
$t->live_element_exists_not('.convos-main-menu .link.dialog', 'no dialogs yet');

{
  local $TODO = 'Should be active unless dialogs';
  $t->live_element_exists('.convos-main-menu .link.active [href="#connection"]');
}

$t->element_is_displayed('.convos-settings');

# This part needs a running irc server and an existing channel called "#test"
if ($ENV{CONVOS_DEFAULT_SERVER}) {
  $t->click_ok('.convos-connection-settings [type="submit"]');

  $t->wait_until(sub { $_->find_element('.convos-create-dialog') });
  $t->send_keys_ok('[placeholder="#channel_name"]', ['tes']);

  $t->wait_until(sub { $_->find_element('.autocomplete [href="#join:#test"]') });
  $t->click_ok('.autocomplete [href="#join:#test"]');

  $t->wait_until(sub { $_->find_element('.convos-main-menu .link.dialog') });
  $t->live_element_exists('.convos-message-enable-notifications');
  $t->live_text_is('header h2', '#test');
  $t->send_keys_ok('.convos-input textarea', ["this is test $NICK", \"enter"]);

  $t->wait_until(sub { $_->find_element(qq(.convos-message [href="#$NICK"])) });
  $t->live_text_like('.convos-message:last-child .message', qr/\bthis is test t\w{7}\b/);

  # test that hitting return joins a dialog
  $t->click_ok('a[href^="#create-dialog/"]');
  $t->wait_until(sub { $_->find_element('.convos-create-dialog') });
  $t->send_keys_ok('[placeholder="#channel_name"]', ['tes']);
  $t->wait_until(sub { $_->find_element('.autocomplete [href="#join:#test"]') });
  $t->send_keys_ok('[placeholder="#channel_name"]', [\'enter']);
  $t->live_text_is('header h2', '#test');
}

done_testing;
