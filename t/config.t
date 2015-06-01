use Mojo::Base -strict;
use Test::More;
use Convos;

{
  my $convos = Convos->new;
  is $convos->config->{backend}, 'Convos::Core::Role::File', 'default backend';
  is $convos->config->{name}, 'Nordaaker', 'default name';
  is $convos->config->{swagger_file}, $convos->home->rel_file('public/api.json'), 'default swagger_file';
  is $convos->config->{hypnotoad}{listen}[0], 'http://*:8080', 'default listen';
  is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
  ok !$convos->sessions->secure, 'insecure sessions';
  like $convos->secrets->[0], qr/^[a-z0-9]{32}$/, 'default secrets';
}

{
  $ENV{CONVOS_BACKEND}           = 'File';
  $ENV{CONVOS_FRONTEND_PID_FILE} = 'pidfile.pid';
  $ENV{CONVOS_ORGANIZATION_NAME} = 'cool.org';
  $ENV{CONVOS_SECRETS}           = 'super:duper:secret';
  $ENV{CONVOS_SECURE_COOKIES}    = 1;
  $ENV{MOJO_LISTEN}              = 'http://*:1234';
  my $convos = Convos->new;
  is $convos->config->{backend}, 'File',     'env backend';
  is $convos->config->{name},    'cool.org', 'env name';
  is $convos->config->{hypnotoad}{listen}[0], 'http://*:1234', 'env listen';
  is $convos->config->{hypnotoad}{pid_file}, 'pidfile.pid', 'env pid_file';
  ok $convos->sessions->secure, 'secure sessions';
  is_deeply($convos->secrets, [qw( super duper secret )], 'env secrets')
}

done_testing;
