#!perl
use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init('Convos',
  {lazy => 1, loc => '/?isMobile=1&_assetpack_reload=false'});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');
my $dialog     = $connection->get_dialog('#test');

$t->wait_for('.convos-login');
t::Selenium->set_window_size($t, 'iphone6');
t::Selenium->selenium_login($t);

$t->wait_for('.convos-main-menu [href="#chat/irc-default/#test"]');

# hidden on small screens
$t->element_is_hidden('.convos-main-menu');
$t->live_element_exists_not('.convos-notifications.is-sidebar');
$t->live_element_exists_not('.convos-sidebar-info.is-sidebar');

my @messages = t::Helper->messages;
$connection->emit(message => $dialog, $_) for splice @messages, 0, 3;
is_at_bottom();

$connection->emit(message => $dialog, $_) for splice @messages, 0, 30;
$connection->emit(message => $dialog, $messages[-1]);
t::Selenium->run_for(0.2);
is_at_bottom();

$t->click_ok('.toggle-main-menu');
$t->element_is_displayed('.convos-main-menu');

$t->wait_for('.convos-main-menu [href="#chat/irc-default/"]');
$t->click_ok('[href="#chat/irc-default/"]');
$t->element_is_hidden('.convos-main-menu');

$connection->emit(message => $dialog, $_) for @messages;
$t->click_ok('.toggle-main-menu');
$t->wait_for('.convos-main-menu [href="#chat/irc-default/#test"]');
$t->click_ok('[href="#chat/irc-default/#test"]');
t::Selenium->run_for(0.3);
is_at_bottom();

done_testing;

sub is_at_bottom {
  $t->browser_log;

  my $s = $t->driver->execute_script(<<'HERE');
var el = document.querySelector(".scroll-element");
return {total: el.scrollHeight, offset: el.offsetHeight, scrolled: el.scrollTop};
HERE

  is $s->{scrolled} + $s->{offset}, $s->{total},
    "scroll: $s->{scrolled} + $s->{offset} == $s->{total}";
}
