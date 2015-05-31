use Mojo::Base -strict;
use Test::More;
use Convos;

{
  my $convos = Convos->new;
  is $convos->config->{name}, 'Nordaaker', 'default name';
  is $convos->config->{swagger_file}, $convos->home->rel_file('public/api.json'), 'default swagger_file';
  is $convos->config->{hypnotoad}{listen}[0], 'http://*:8080', 'default listen';
  is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
  like $convos->secrets->[0], qr/^[a-z0-9]{32}$/, 'default secrets';
}

{
  $ENV{CONVOS_ORGANIZATION_NAME} = 'cool.org';
  $ENV{CONVOS_FRONTEND_PID_FILE} = 'pidfile.pid';
  $ENV{MOJO_LISTEN}              = 'http://*:1234';
  $ENV{CONVOS_SECRETS}           = 'super:duper:secret';
  my $convos = Convos->new;
  is $convos->config->{name}, 'cool.org', 'env name';
  is $convos->config->{hypnotoad}{listen}[0], 'http://*:1234', 'env listen';
  is $convos->config->{hypnotoad}{pid_file}, 'pidfile.pid', 'env pid_file';
  is_deeply($convos->secrets, [qw( super duper secret )], 'env secrets')
}

done_testing;
