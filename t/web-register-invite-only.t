#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

$t->get_ok('/api/user')->status_is(401);

$t->post_ok('/api/user/superman@example.com/invite')->status_is(401)
  ->json_is('/errors/0/message', 'Need to log in first.');

$t->post_ok('/api/user/superman@example.com/invite', {'X-Local-Secret' => 'abc'})->status_is(401)
  ->json_is('/errors/0/message', 'Need to log in first.');

note 'first user does not need invite link';
$t->get_ok('/register')->status_is(200)->content_like(qr{"first_user":true});
my %register = (email => 'first@convos.by', password => 'firstpassword');
$t->post_ok('/api/user/register', json => \%register)->status_is(200);
$t->get_ok('/api/user/logout.html')->status_is(302);

note 'second user needs invite link';
$t->get_ok('/register')->status_is(200)->content_unlike(qr{"first_user"});
$t->get_ok(
  "/register?email=superman\@example.com&exp=1572900000&token=27c4e74740ce492d24ff843f7e788baab010d24"
)->status_is(410);

$t->get_ok(
  "/register?email=superman\@example.com&exp=xyz&token=27c4e74740ce492d24ff843f7e788baab010d24")
  ->status_is(410);

$t->post_ok(
  '/api/user/superman@example.com/invite.json',
  {'X-Local-Secret' => $t->app->settings('local_secret')}
)->status_is(200);
my $url = $t->tx->res->text;
$url = $url =~ s!(http.*)!$1! ? $1 : 'http://invalid';
$url = Mojo::URL->new($url);
is $url->query->param('email'), 'superman@example.com', 'register url email';
ok $url->query->param('exp'),   'register url exp';
ok $url->query->param('token'), 'register url token';

note "url=$url";
$t->get_ok(substr $url, 0, -1)->status_is(400)->content_like(qr{"status":400})
  ->content_unlike(qr{"password"}, 'password is not part of window.__convos');

$t->get_ok($url)->status_is(200)->content_like(qr{"existing_user":false})
  ->content_like(qr{"status":200})->content_like(qr{"open_to_public":false})
  ->content_unlike(qr{"password"}, 'password is not part of window.__convos');

%register = (email => $url->query->param('email'), password => 'tooshort0');
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

$register{exp} = $url->query->param('exp');
$t->post_ok('/api/user/register', json => \%register)->status_is(200)
  ->json_is('/email', $register{email});

$t->get_ok('/api/user')->status_is(200);

done_testing;
