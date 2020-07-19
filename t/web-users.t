#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_OPEN_TO_PUBLIC} = 1;

my $t = t::Helper->t;

note 'No user';
$t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->get_ok('/api/users')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');

note 'First user';
$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => '1234567890'})->status_is(200)
  ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
$t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
  ->json_is('/users/1', undef);
$t->get_ok('/api/user/logout')->status_is(200);

note 'Second user';
$t->post_ok('/api/user/register',
  json => {email => 'superwoman@example.com', password => '1234567890'})->status_is(200);
$t->get_ok('/api/users')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->get_ok('/api/user/logout')->status_is(200);

note 'First user again';
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => '1234567890'})
  ->status_is(200);
$t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
  ->json_is('/users/1/email', 'superwoman@example.com')->json_is('/users/2', undef);

done_testing;
