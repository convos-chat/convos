#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND}           = 'Convos::Core::Backend';
$ENV{CONVOS_FORCED_IRC_SERVER} = 'chat.example.com:1234';
my $t = t::Helper->t;

my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->post_ok('/api/connections', json => {url => 'irc://irc.perl.org'})->status_is(200);
$t->post_ok('/api/connections', json => {url => 'irc://chat.freenode.net'})->status_is(400)
  ->json_is('/errors/0/message', 'Connection already exists.');
$t->get_ok('/api/connections')->status_is(200)
  ->json_is('/connections/0/connection_id', 'irc-example')
  ->json_is('/connections/0/name',          'example')
  ->json_is('/connections/0/url',           'irc://chat.example.com:1234?forced=1&nick=superman');

$t->post_ok('/api/connection/irc-example', json => {url => 'irc://irc.perl.org'})->status_is(200);
$t->get_ok('/api/connections')->status_is(200)
  ->json_is('/connections/0/connection_id', 'irc-example')
  ->json_is('/connections/0/name',          'example')
  ->json_is('/connections/0/url',           'irc://chat.example.com:1234?forced=1');

done_testing;
