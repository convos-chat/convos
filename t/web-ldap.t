#!perl
use lib '.';
use t::Helper;

plan skip_all => 'CONVOS_AUTH_LDAP_URL=...' unless $ENV{CONVOS_AUTH_LDAP_URL};

$ENV{CONVOS_PLUGINS} = 'Convos::Plugin::Auth::LDAP';
$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

$t->get_ok('/api/user')->status_is(401);

subtest 'not authorized' => sub {
  $t->post_ok('/api/user/login',
    json => {email => 'superwoman@example.com', password => 'superduper'})->status_is(400);
};

subtest 'authorized' => sub {
  ok !$t->app->core->get_user('superman@example.com'), 'superman does not yet exist';
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 'secret'})
    ->status_is(200)->json_is('/email', 'superman@example.com');
  ok $t->app->core->get_user('superman@example.com'), 'superman account was created';

  $t->get_ok('/api/user')->status_is(200);
  $t->get_ok('/api/user/logout')->status_is(302);
};

subtest 'fallback to local user' => sub {
  $t->app->core->user({email => 'superwoman@example.com'})->set_password('superduper');
  $t->post_ok('/api/user/login',
    json => {email => 'superwoman@example.com', password => 'superduper'})->status_is(200)
    ->json_is('/email', 'superwoman@example.com');
};

done_testing;
