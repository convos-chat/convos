use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = Test::Mojo->new('Convos');
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->get_ok('/1.0/connections')->status_is(401);
$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->get_ok('/1.0/connection/IRC/localhost/rooms')->status_is(404)
  ->json_is('/errors/0/message', 'Connection not found.');

$t->post_ok('/1.0/connection', json => {protocol => 'IRC', server => 'localhost:3123'})->status_is(200);
$t->get_ok('/1.0/connection/IRC/localhost/rooms')->status_is(200)->content_is('[]');

done_testing;
