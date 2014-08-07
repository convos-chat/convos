use Mojo::Base -base;
use Test::Mojo;
use Test::More;

{
  $ENV{CONVOS_ORGANIZATION_NAME} = '';
  my $t = Test::Mojo->new('Convos');
  $t->app->config(redis_version => 1, hostname_is_set => 1);
  $t->get_ok('/login')->text_is('title', 'Nordaaker - Login');
}

{
  $ENV{CONVOS_ORGANIZATION_NAME} = 'The Lost Boys';
  my $t = Test::Mojo->new('Convos');
  $t->app->config(redis_version => 1, hostname_is_set => 1);
  $t->get_ok('/login')->text_is('title', 'The Lost Boys - Login');
}

done_testing;
