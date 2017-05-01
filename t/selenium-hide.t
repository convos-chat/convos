#!perl
use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});

$t->navigate_ok('/?hide=header,sidebar,menu');
$t->wait_for('.convos-chat');
$t->element_is_hidden('.convos-header-links');
$t->element_is_hidden('.convos-main-menu');
$t->element_is_hidden('.is-sidebar');
$t->element_is_hidden('header');

$t->navigate_ok('/?hide=header');
$t->wait_for('.convos-chat');
$t->element_is_hidden('.convos-header-links');
$t->element_is_displayed('.convos-main-menu');
$t->element_is_displayed('.is-sidebar');
$t->element_is_hidden('header');

$t->navigate_ok('/?hide=sidebar,menu');
$t->wait_for('.convos-chat');
$t->element_is_hidden('.convos-header-links');
$t->element_is_hidden('.convos-main-menu');
$t->element_is_hidden('.is-sidebar');
$t->element_is_displayed('header');

$t->navigate_ok('/?hide=menu');
$t->wait_for('.convos-chat');
$t->element_is_displayed('.convos-header-links');
$t->element_is_hidden('.convos-main-menu');
$t->element_is_displayed('.is-sidebar');
$t->element_is_displayed('header');

done_testing;
