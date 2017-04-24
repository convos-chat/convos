#!perl
use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init('Convos');

$t->navigate_ok('/?_vue=false');
$t->wait_until(sub { $_->find_element('p.message') });
$t->live_text_like('p.message', qr{Loading Convos should not take too long});

$t->navigate_ok('/?_error=Ooops');
$t->wait_until(sub { $_->find_element('p.alert') });
$t->live_text_is('p.alert', 'Ooops');

$t->click_ok('a.btn');
$t->wait_until(sub { $_->find_element('.convos-login') });

done_testing;
