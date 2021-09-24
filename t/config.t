#!perl
use lib '.';
use t::Helper;
use Mojo::File 'path';

delete $ENV{CONVOS_SECRETS};
my $convos = Convos->new;
my $secret;

subtest 'defaults' => sub {
  $secret = $convos->secrets->[0];
  is $convos->config->{backend}, 'Convos::Core::Backend::File', 'default backend';
  is $convos->core->settings->default_connection, 'irc://irc.libera.chat:6697/%23convos',
    'default default_connection';
  is $convos->config->{home}, $ENV{CONVOS_HOME}, 'home from ENV';
  is $convos->core->settings->organization_name, 'Convos',              'default organization_name';
  is $convos->core->settings->organization_url,  'https://convos.chat', 'default organization_url';
  is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
  like $convos->core->settings->local_secret, qr/^\w{40}$/, 'generated local_secret';
  like $secret, qr/^[a-z0-9]{40}$/, 'default secrets';
};

subtest 'make sure we load the same secret' => sub {
  is(Convos->new->secrets->[0], $secret, 'reusing generated secret');
};

subtest 'loading plugins and default from environment' => sub {
  my $i = 0;
  Mojo::File->new($ENV{CONVOS_HOME}, 'settings.json')->remove;
  $i++;

  my @plugins;
  Mojo::Util::monkey_patch(
    Convos => plugin => sub {
      my $self = shift;
      return $self->Mojolicious::plugin(@_) unless $_[0] =~ /Plugin[A-Z\d]/;
      push @plugins, ($i, @_);
    }
  );

  $ENV{CONVOS_PLUGINS}           = 'PluginX';
  $ENV{CONVOS_BACKEND}           = 'Convos::Core::Backend';
  $ENV{CONVOS_FRONTEND_PID_FILE} = 'pidfile.pid';
  $ENV{CONVOS_SECRETS}           = 'super,duper,secret';
  $ENV{CONVOS_SECURE_COOKIES}    = 1;
  $convos                        = Convos->new;
  is $convos->config->{backend}, 'Convos::Core::Backend', 'env backend';
  is_deeply($convos->secrets, [qw(super duper secret)], 'env secrets');
  is $plugins[1], 'PluginX', 'PluginX';
};

done_testing;
