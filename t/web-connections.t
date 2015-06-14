use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = Test::Mojo->new('Convos');
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->get_ok('/1.0/connections')->status_is(401);
$t->post_ok('/1.0/connection', json => {protocol => '', server => ''})->status_is(401);
$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->get_ok('/1.0/connections')->status_is(200)->content_is('[]');

$t->post_ok('/1.0/connection', json => {protocol => 'IRC', server => 'localhost:3123'})->status_is(200)
  ->json_is('/path', '/superman@example.com/IRC/localhost');
$t->post_ok('/1.0/connection', json => {protocol => 'IRC', server => 'irc://irc.perl.org:6667'})->status_is(200)
  ->json_is('/path', '/superman@example.com/IRC/magnet');

$t->post_ok('/1.0/connection', json => {protocol => 'Foo', server => 'irc://irc.perl.org:6667'})->status_is(400)
  ->json_is('/errors/0', {message => 'Could not find class from protocol.', path => '/data/protocol',});

$user->connection(IRC => 'localhost')->state('connected');
$t->get_ok('/1.0/connections')->status_is(200)->json_is(
  '/0',
  {
    path  => '/superman@example.com/IRC/localhost',
    name  => 'localhost',
    state => 'connected',
    url   => 'irc://localhost:3123'
  }
  )->json_is(
  '/1',
  {
    path  => '/superman@example.com/IRC/magnet',
    name  => 'magnet',
    state => 'connecting',
    url   => 'irc://irc.perl.org:6667'
  }
  );

done_testing;
