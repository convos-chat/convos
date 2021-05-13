use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

$t->app->core->settings->default_connection(Mojo::URL->new('irc://chat.example.com:1234'))
  ->forced_connection(true)->open_to_public(true);

$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

$t->post_ok('/api/connections', json => {url => 'irc://irc.perl.org'})->status_is(400);
$t->post_ok('/api/connections', json => {url => 'irc://chat.freenode.net'})->status_is(400)
  ->json_is('/errors/0/message', 'Will only accept forced connection URL.');

$t->get_ok('/api/connections')->status_is(200)
  ->json_is('/connections/0/connection_id', 'irc-example')
  ->json_is('/connections/0/name',          'example')
  ->json_is('/connections/0/url',           'irc://chat.example.com:1234?nick=superman&tls=1');

# The new URL will be ignored
$t->post_ok('/api/connection/irc-example',
  json => {url => 'irc://irc.perl.org?nick=superduper&tls=0&tls_verify=0'})->status_is(200);

$t->get_ok('/api/connections')->status_is(200)
  ->json_is('/connections/0/connection_id', 'irc-example')
  ->json_is('/connections/0/name',          'example')
  ->json_is('/connections/0/url', 'irc://chat.example.com:1234?tls=0&tls_verify=0&nick=superduper');

done_testing;
