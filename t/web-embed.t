#!perl
use lib '.';
use t::Helper;
my $t = t::Helper->t;

my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

$t->get_ok('/api/embed')->status_is(400);
$t->get_ok('/api/embed?url=/foo')->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->get_ok('/api/embed.json')->status_is(400);

my $host_port = $t->ua->server->nb_url->host_port;
$t->get_ok("/api/embed.json?url=http://$host_port")->status_is(200)->json_has('/html');

# from chache
$t->get_ok("/api/embed.json?url=http://$host_port")->status_is(200)->header_is('X-Cached' => 1)
  ->json_is('/title', 'Better group chat')->json_like('/html', qr{Better group chat});

done_testing;
