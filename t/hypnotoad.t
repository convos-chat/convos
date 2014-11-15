use Mojo::Base -base;
use Test::Mojo;
use Test::More;

{
  my $t = Test::Mojo->new('Convos');
  is_deeply $t->app->config->{hypnotoad}{listen}, [qw( http://*:8080 )], 'hypnotoad listen';

  local $SIG{USR2} = sub { };
  eval { $t->app->_embed_backend };
  like $@, qr{Cannot start embedded backend}, 'cannot embed with hypnotoad';
}

{
  local $ENV{MOJO_LISTEN}        = 'http://*:8080,https://*:8444?key=/tmp/foo.key';
  local $ENV{MOJO_REVERSE_PROXY} = '1';

  my $t = Test::Mojo->new('Convos');
  is_deeply $t->app->config->{hypnotoad}{listen}, [qw( http://*:8080 https://*:8444?key=/tmp/foo.key )],
    'hypnotoad listen from env';
}

done_testing;
