use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->get_ok('/api/connections')->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/connection/irc-localhost/rooms')->status_is(404)
  ->json_is('/errors/0/message', 'Connection not found.');

$t->post_ok('/api/connections', json => {url => 'irc://localhost:3123'})->status_is(200);
$t->get_ok('/api/connection/irc-localhost/rooms')->status_is(200)->json_is('/rooms', []);

done_testing;
