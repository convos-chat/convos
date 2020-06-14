#!perl
use lib '.';
use t::Helper;
use Mojo::File 'path';

note 'Test defaults';
delete $ENV{CONVOS_SECRETS};
my $i      = 0;
my $convos = Convos->new;
my $secret = $convos->secrets->[0];
is $convos->config->{backend}, 'Convos::Core::Backend::File', 'default backend';
is $convos->settings('default_connection'), 'irc://chat.freenode.net:6697/%23convos',
  'default default_connection';
is $convos->config->{home}, $ENV{CONVOS_HOME}, 'home from ENV';
is $convos->settings('organization_name'), 'Convos',              'default organization_name';
is $convos->settings('organization_url'),  'https://convos.chat', 'default organization_url';
is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
like $convos->settings('local_secret'), qr/^\w{40}$/, 'generated local_secret';
like $secret, qr/^[a-z0-9]{40}$/, 'default secrets';

note 'Make sure we load the same secret';
is(Convos->new->secrets->[0], $secret, 'reusing generated secret');

note 'Test loading plugins and default from environment';
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

$ENV{CONVOS_PLUGINS}            = 'PluginX';
$ENV{CONVOS_BACKEND}            = 'Convos::Core::Backend';
$ENV{CONVOS_DEFAULT_CONNECTION} = 'irc.example.com';
$ENV{CONVOS_FRONTEND_PID_FILE}  = 'pidfile.pid';
$ENV{CONVOS_ORGANIZATION_NAME}  = 'cool.org';
$ENV{CONVOS_ORGANIZATION_URL}   = 'https://thorsen.pm';
$ENV{CONVOS_SECRETS}            = 'super,duper,secret';
$ENV{CONVOS_SECURE_COOKIES}     = 1;
$convos                         = Convos->new;
is $convos->config->{backend}, 'Convos::Core::Backend', 'env backend';
is $convos->settings('default_connection'), 'irc://irc.example.com', 'env default_connection';
is $convos->settings('forced_connection'),  0,                       'default forced_connection';
is $convos->settings('organization_name'),  'cool.org',              'env organization_name';
is $convos->settings('organization_url'),   'https://thorsen.pm',    'env organization_url';
is_deeply($convos->secrets, [qw(super duper secret)], 'env secrets');
is $plugins[1], 'PluginX', 'PluginX';

note 'Testing forced irc server';
Mojo::File->new($ENV{CONVOS_HOME}, 'settings.json')->remove;
$ENV{CONVOS_FORCED_IRC_SERVER} = 'irc://localhost:1234/%23cool_channel';
$convos = Convos->new;
is $convos->settings('default_connection'), 'irc://localhost:1234/%23cool_channel',
  'forced default_connection';
is $convos->settings('forced_connection'), 1, 'env CONVOS_FORCED_IRC_SERVER';

done_testing;
