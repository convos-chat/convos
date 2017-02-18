use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, loc => '/?isMobile=1'});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');
my $dialog     = $connection->get_dialog('#test');

$t->wait_until(sub { $_->find_element('.convos-login') });
t::Selenium->set_window_size($t, 'iphone6');
t::Selenium->selenium_login($t);

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#test"]') });

# hidden on small screens
$t->element_is_hidden('.convos-main-menu');
$t->live_element_exists_not('.convos-notifications.is-sidebar');
$t->live_element_exists_not('.convos-sidebar-info.is-sidebar');
is $t->driver->execute_script(js_get_dialog('.atBottom')), 1, 'atBottom';

done_testing;

sub js_get_dialog {
  return qq/return Convos.vm.user.getConnection("irc-default").getDialog("#test")$_[0]/;
}
