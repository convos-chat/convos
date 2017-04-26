#!perl
use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init('Convos');

$t->navigate_ok('/?_vue=false');
$t->wait_for('p.message');
$t->live_text_like('p.message', qr{Loading Convos should not take too long});

$t->navigate_ok('/?_error=Ooops');
$t->wait_for('p.alert');
$t->live_text_is('p.alert', 'Ooops');

$t->click_ok('a.btn');
$t->wait_for('.convos-login');

done_testing;
