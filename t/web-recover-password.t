#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

note 'Log in admin';
$t->app->core->user({email => 'admin@example.com'})->set_password('adm1n')->role(give => 'admin');
$t->post_ok('/api/user/login', json => {email => 'admin@example.com', password => 'adm1n'})
  ->status_is(200);

note 'Create recover user and recover url';
$t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$t->post_ok('/api/user/superman@example.com/invite.json')->status_is(200)
  ->json_is('/existing', true)->json_like('/expires', qr{^\d+-\d+-\d+})
  ->json_like('/url', qr{^http});
my $recover_url = Mojo::URL->new($t->tx->res->json->{url});

note 'Log out admin';
$t->get_ok('/api/user/logout')->status_is(302);

note 'Let recover user do the rest';
$t->get_ok(substr $recover_url, 0, -1)->status_is(400)
  ->element_exists(qq(meta[name="convos:status"][content="400"]));

note $recover_url;
$t->get_ok($recover_url)->status_is(200)
  ->element_exists(qq(meta[name="convos:existing_user"][content="yes"]))
  ->element_exists(qq(meta[name="convos:status"][content="200"]));


my %register = (email => $recover_url->query->param('email'), password => 'tooshort0');
$t->post_ok('/api/user/register', json => \%register)->status_is(400)
  ->json_is('/errors/0/path', '/body/password');

$register{password} = 'longenough';
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message', 'Convos registration is not open to public.');

$register{token} = $recover_url->query->param('token');
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message',
  'Invalid token. You have to ask your Convos admin for a new link.');

$t->get_ok('/api/user')->status_is(401);

$register{email} = 'superwoman@example.com';
$register{exp}   = $recover_url->query->param('exp');
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message',
  'Invalid token. You have to ask your Convos admin for a new link.');

$t->get_ok('/api/user')->status_is(401);

$register{email} = 'superman@example.com';
$t->post_ok('/api/user/register', json => \%register)->status_is(200)
  ->json_is('/email', $register{email});

$t->get_ok('/api/user')->status_is(200);

done_testing;
