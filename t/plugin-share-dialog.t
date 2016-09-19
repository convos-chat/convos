use t::Helper;

$ENV{CONVOS_PLUGINS} = 'ShareDialog';

my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

for my $m (qw(get_ok post_ok)) {
  $t->$m('/api/connection/irc-localhost/dialog/%23convos/share')->status_is(401);
}

$t->get_ok('/log/1234567890/irc-localhost/%23convos')->status_is(404);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$user->connection({name => 'localhost', protocol => 'irc'})
  ->dialog({name => '#Convos', frozen => ''});
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/share/status')->status_is(200)
  ->json_is('/shared', false);

$t->post_ok('/api/connection/irc-localhost/dialog/%23convos/share')->status_is(200)
  ->json_like('/id', qr/^\w{10}$/);

my $id = $t->tx->res->json->{id};
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/share')->status_is(302)
  ->header_like(Location => qr{/log/$id/irc-localhost/\%23convos$});

$t->get_ok("/log/1234567890/irc-localhost/%23convos")->status_is(404);
$t->get_ok("/log/$id/irc-localhost/%23convos")->status_is(200);

$t->delete_ok('/api/connection/irc-localhost/dialog/%23convos/share')->status_is(200)
  ->json_is('/id', undef);
$t->get_ok("/log/$id/irc-localhost/%23convos")->status_is(404);

done_testing;
