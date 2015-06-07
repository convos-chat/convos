use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = Test::Mojo->new('Convos');

$t->get_ok('/1.0/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->delete_ok('/1.0/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->post_ok('/1.0/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');

$t->post_ok('/1.0/user/register', json => {email => 'superman', password => 'xyz'})->status_is(400)
  ->json_is('/errors/0', {message => 'Does not match email format.', path => '/data/email'})
  ->json_is('/errors/1', {message => 'String is too short: 3/6.',    path => '/data/password'});

$t->post_ok('/1.0/user/register', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200)
  ->json_is('/avatar', '')->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^\d+$/);

$t->post_ok('/1.0/user')->status_is(200)->json_is('/avatar', '');
my $registered = $t->tx->res->json->{registered};
$t->post_ok('/1.0/user', json => {avatar => 'avatar@example.com'})->status_is(200)
  ->json_is('/avatar', 'avatar@example.com');

$t->get_ok('/1.0/user')->status_is(200)
  ->json_is('', {avatar => 'avatar@example.com', email => 'superman@example.com', registered => $registered});

$t->delete_ok('/1.0/user')->status_is(400)->json_is('/errors/0/message', 'You are the only user left.');

done_testing;
