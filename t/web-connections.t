use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = Test::Mojo->new('Convos');
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->get_ok('/1.0/connections')->status_is(401);
$t->post_ok('/1.0/user/authenticate', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->get_ok('/1.0/connections')->status_is(200)->content_is('[]');

# order does not matter
$user->connection(IRC => 'localhost')->state('connected')->url->parse('irc://localhost:3123');
$user->connection(IRC => 'perl-org');

$t->get_ok('/1.0/connections')->status_is(200)->json_is(
  '/0',
  {
    path  => '/superman@example.com/IRC/localhost',
    name  => 'localhost',
    state => 'connected',
    url   => 'irc://localhost:3123'
  }
  )
  ->json_is('/1', {path => '/superman@example.com/IRC/perl-org', name => 'perl-org', state => 'connecting', url => ''});

done_testing;
