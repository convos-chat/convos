#!perl
use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default')->state('connected');

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#test"]') });

$connection->_event_join(
  {event => 'privmsg', prefix => 'batgirl!batgirl@i.love.debian.org', params => ['#test']});

$t->wait_until(sub { $_->find_element('.convos-sidebar-info [href="#chat:batgirl"]'); });

$connection->_event_join(
  {event => 'privmsg', prefix => "$NICK!$NICK\@i.love.debian.org", params => ['#foo']});

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#foo"]') });
$t->click_ok('.convos-main-menu [href="#chat/irc-default/#foo"]');
$t->live_element_exists_not('.convos-sidebar-info [href="#chat:batgirl"]');

$connection->_event_nick(
  {event => 'quit', prefix => 'batgirl!batgirl@i.love.debian.org', params => ['batwoman']});

$t->live_element_exists_not('.convos-sidebar-info [href="#chat:batwoman"]');

$t->click_ok('.convos-main-menu [href="#chat/irc-default/#test"]');
$t->wait_until(
  sub { $_->find_element('.convos-main-menu .active [href="#chat/irc-default/#test"]') });
$t->wait_until(sub { $_->find_element('.convos-sidebar-info [href="#chat:batwoman"]'); });

done_testing;
