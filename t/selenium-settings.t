#!perl
use lib '.';
use t::Selenium;

# Needed for https://github.com/Nordaaker/convos/issues/344
$ENV{CONVOS_DEFAULT_SERVER} = 'dummy.example.com:6697';

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');

$t->wait_for('.convos-main-menu [href="#chat/irc-default/"]');
$t->click_ok('.convos-main-menu [href="#chat/irc-default/"]');

$t->wait_for('.convos-sidebar-info [type="submit"]');
$t->click_ok('.convos-sidebar-info [type="submit"]');

$t->wait_for(0.2);
is $t->driver->execute_script('return Convos.settings.main'), "#chat/irc-default/",
  'still in connection settings';

$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');
$t->send_keys_ok('.convos-connection-settings [type="password"]', ['se%!+cret', \'tab']);
$t->click_ok('.convos-connection-settings [type="submit"]');
$t->wait_for(0.2);

is $connection->url->to_unsafe_string,
  "irc://:se%25!+cret\@dummy.example.com:6697?nick=$NICK&tls=1", 'url with password';

$t->send_keys_ok('.convos-connection-settings [name="server"]', [(\'backspace') x 30]);
$t->send_keys_ok('.convos-connection-settings [name="server"]', ['irc.example.com:6668', \'tab']);
$t->send_keys_ok(undef, [\'tab']);                             # wanted state
$t->send_keys_ok(undef, ['superduper', \'tab']);               # nick
$t->send_keys_ok(undef, [\'tab']);                             # tls
$t->send_keys_ok(undef, [\'tab']);                             # advanced settings
$t->send_keys_ok(undef, ['<user>', \'tab']);                   # username
$t->send_keys_ok(undef, ['s3cr#t', \'tab']);                   # password
$t->send_keys_ok(undef, [' /msg nickserv hey!', \'enter']);    # on connect commands
$t->send_keys_ok(undef, ['/nick whatever  ', \'tab']);         # on connect commands
$t->click_ok('.convos-connection-settings [type="submit"]');
$t->wait_for(0.2);

is $connection->url->to_unsafe_string,
  "irc://%3Cuser%3E:s3cr%23t\@irc.example.com:6668?nick=superduper&tls=1",
  'url with username, password and nick';

$t->driver->refresh;
$t->wait_for('.convos-sidebar-info [type="submit"]');
$t->click_ok('.convos-connection-settings [for="form_advanced_settings"]');
$t->send_keys_ok(undef, [\'tab']);                             # goto username
$t->send_keys_ok(undef, [(\'backspace') x 30]);                # username
$t->click_ok('.convos-connection-settings [type="submit"]');

$t->t::Selenium::form_is(
  '.convos-connection-settings input, .convos-connection-settings textarea',
  [
    "irc.example.com:6668", "Connected", "superduper", "on", "on", "", "s3cr#t",
    "/msg nickserv hey!\n/nick whatever"
  ],
);

is $connection->url->to_unsafe_string,
  "irc://:s3cr%23t\@irc.example.com:6668?nick=superduper&tls=1", 'url without username';

# $t->browser_log;

done_testing;
