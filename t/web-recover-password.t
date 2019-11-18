#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

$t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->get_ok('/api/user')->status_is(401);

$t->post_ok('/api/user/invite/superman@example.com',
  {'X-Local-Secret' => $t->app->settings('local_secret')})->status_is(200);

my $url = $t->tx->res->text;
$url = $url =~ s!(http.*)!$1! ? $1 : 'http://invalid';
$url = Mojo::URL->new($url);

$t->get_ok(substr $url, 0, -1)->status_is(400)->content_like(qr{"status":400});

$t->get_ok($url)->status_is(200)->content_like(qr{"existing_user":true})
  ->content_like(qr{"status":200});

my %register = (email => $url->query->param('email'), password => 'tooshort0');
$t->post_ok('/api/user/register', json => \%register)->status_is(400)
  ->json_is('/errors/0/path', '/body/password');

$register{password} = 'longenough';
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message', 'Convos registration is not open to public.');

$register{token} = $url->query->param('token');
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message',
  'Invalid token. You have to ask your Convos admin for a new link.');

$t->get_ok('/api/user')->status_is(401);

$register{email} = 'superwoman@example.com';
$register{exp}   = $url->query->param('exp');
$t->post_ok('/api/user/register', json => \%register)->status_is(401)
  ->json_is('/errors/0/message',
  'Invalid token. You have to ask your Convos admin for a new link.');

$t->get_ok('/api/user')->status_is(401);

$register{email} = 'superman@example.com';
$t->post_ok('/api/user/register', json => \%register)->status_is(200)
  ->json_is('/email', $register{email});

$t->get_ok('/api/user')->status_is(200);

done_testing;
