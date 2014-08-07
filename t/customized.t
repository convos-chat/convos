use Mojo::Base -base;
use Test::Mojo;
use Test::More;

plan skip_all => 'Could not find ./t directory' unless -d 't';

{
  $ENV{CONVOS_ORGANIZATION_NAME} = 'Too cool';
  $ENV{CONVOS_TEMPLATES}         = 't';
  my $t = Test::Mojo->new('Convos');

  $t->app->config(redis_version => 1, hostname_is_set => 1);
  $t->get_ok('/login')->text_is('title', 'Too cool - Login')
    ->element_exists('img[src="http://convos.by/images/screenshot.jpg"]');
  $t->get_ok('/register')->text_is('title', 'Too cool - Register')->text_is('.register-footer', 'Dummy text');
}

done_testing;
