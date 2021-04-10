#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND}          = 'Convos::Core::Backend';
$ENV{CONVOS_CHECK_FOR_UPDATE} = '/api/version';
my $t = t::Helper->t;

note 'need to log in first';
$t->post_ok('/api/settings', json => {open_to_public => true})->status_is(401);

note 'add admin user';
$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

note 'get default settings';
$t->get_ok('/api/settings')->status_is(200)
  ->json_is('/check_for_update',
  {available_version => Convos->VERSION, interval => 86400, last_checked => 0});

note 'version check';
$t->get_ok('/api/version')->status_is(400)->json_is('/errors/0/path', '/app_id')
  ->json_is('/errors/1/path', '/running');
$t->get_ok('/api/version?app_id=356a192b7913b04c54574d18c28d46e6395428ab&running=foo')
  ->status_is(400)->json_is('/errors/0/path', '/running');
$t->get_ok('/api/version?app_id=356a192b7913b04c54574d18c28d46e6395428ab&running=4')
  ->status_is(200)->json_is('/available_version', Convos->VERSION)
  ->json_is('/update_available', true);
$t->get_ok("/api/version?app_id=356a192b7913b04c54574d18c28d46e6395428ab&running=$Convos::VERSION")
  ->status_is(200)->json_is('/update_available', false);

# $t->app->ua($t->ua);
# $t->app->check_for_update_p->wait;

done_testing;
