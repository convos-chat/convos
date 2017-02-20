use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/"]'); });
$t->click_ok('.convos-main-menu [href="#chat/irc-default/"]');

$t->wait_until(sub { $_->find_element('.convos-sidebar-info [type="submit"]'); });
$t->click_ok('.convos-sidebar-info [type="submit"]');

t::Selenium->run_for(0.2);
is $t->driver->execute_script('return Convos.settings.main'), "#chat/irc-default/",
  'still in connection settings';

done_testing;
