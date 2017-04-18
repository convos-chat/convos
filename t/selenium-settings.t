use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');
my $form;

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/"]'); });
$t->click_ok('.convos-main-menu [href="#chat/irc-default/"]');

$t->wait_until(sub { $_->find_element('.convos-sidebar-info [type="submit"]'); });
$t->click_ok('.convos-sidebar-info [type="submit"]');

t::Selenium->run_for(0.2);
is $t->driver->execute_script('return Convos.settings.main'), "#chat/irc-default/",
  'still in connection settings';

$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');
$t->send_keys_ok('.convos-connection-settings [type="password"]', ['se%!+cret', \'tab']);
$t->click_ok('.convos-connection-settings [type="submit"]');
t::Selenium->run_for(0.2);

is $connection->url->to_unsafe_string, "irc://:se%25!+cret\@localhost?nick=$NICK",
  'url with password';

$t->send_keys_ok('.convos-connection-settings [name="server"]', [(\'backspace') x 10]);
$t->send_keys_ok('.convos-connection-settings [name="server"]', ['irc.example.com', \'tab']);
$t->send_keys_ok(undef, [\'tab']);                             # wanted state
$t->send_keys_ok(undef, ['superduper', \'tab']);               # nick
$t->send_keys_ok(undef, [\'tab']);                             # tls
$t->send_keys_ok(undef, [\'tab']);                             # advanced settings
$t->send_keys_ok(undef, ['<user>', \'tab']);                   # username
$t->send_keys_ok(undef, ['s3cr#t', \'tab']);                   # password
$t->send_keys_ok(undef, [' /msg nickserv hey!', \'enter']);    # on connect commands
$t->send_keys_ok(undef, ['/nick whatever  ', \'tab']);         # on connect commands
$t->click_ok('.convos-connection-settings [type="submit"]');
t::Selenium->run_for(0.2);

is $connection->url->to_unsafe_string,
  "irc://%3Cuser%3E:s3cr%23t\@irc.example.com?nick=superduper&tls=0",
  'url with username, password and nick';

$t->driver->refresh;
$t->wait_until(sub { $_->find_element('.convos-sidebar-info [type="submit"]'); });
$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');

$form
  = $t->driver->execute_script(
  'return [].map.call(document.querySelectorAll(".convos-connection-settings input, .convos-connection-settings textarea"), function(el) { return el.value });'
  );
is_deeply(
  $form,
  [
    "irc.example.com", "Connected", "superduper", "on", "on", "<user>", "s3cr#t",
    "/msg nickserv hey!\n/nick whatever"
  ],
  'form data'
) or diag join ", ", @$form;

# TODO: test form fields

# $t->browser_log;

done_testing;
