use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = Test::Mojo->new('Convos');
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->get_ok('/1.0/conversations')->status_is(200)->json_is('/conversations', []);

no warnings 'redefine';
require Mojo::IRC::UA;
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };

# order does not matter
$user->connection(IRC => 'localhost', {})->join_conversation('#private',       sub { });
$user->connection(IRC => 'perl-org',  {})->join_conversation('#oslo.pm',       sub { });
$user->connection(IRC => 'localhost', {})->join_conversation('#Convos s3cret', sub { });

$t->get_ok('/1.0/conversations')->status_is(200)->json_is(
  '/conversations/0',
  {
    active => 1,
    topic  => '',
    frozen => '',
    name   => '#Convos',
    path   => '/superman@example.com/IRC/localhost/#convos',
    id     => '#convos',
    users  => {}
  }
  )->json_is(
  '/conversations/1',
  {
    active => 1,
    topic  => '',
    frozen => '',
    name   => '#private',
    path   => '/superman@example.com/IRC/localhost/#private',
    id     => '#private',
    users  => {}
  }
  )->json_is(
  '/conversations/2',
  {
    active => 1,
    topic  => '',
    frozen => '',
    name   => '#oslo.pm',
    path   => '/superman@example.com/IRC/perl-org/#oslo.pm',
    id     => '#oslo.pm',
    users  => {}
  }
  );

done_testing;
