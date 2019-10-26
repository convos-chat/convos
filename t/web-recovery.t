#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND}      = 'Convos::Core::Backend';
$ENV{CONVOS_COMMAND_LINE} = 1;
my $t    = t::Helper->t;
my $time = time - 1;

$t->get_ok("/user/recover/superman\@example.com/$time/27c4e74740ce492d24ff843f7e788baab010d24")
  ->status_is(410);

$t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$t->get_ok('/api/user')->status_is(401);

$t->get_ok('/user/recover/superman@example.com')->status_is(200)
  ->content_like(qr!/superman\@example\.com/\d+/\w{40}$!);
my $url = $t->tx->res->text;

$t->get_ok(substr $url, 0, -1)->status_is(400);
$t->get_ok('/api/user')->status_is(401);

$t->get_ok($url)->status_is(302)->header_is(Location => '/');
$t->get_ok('/')->status_is(200);

done_testing;
