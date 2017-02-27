use lib '.';
use t::Helper;
use Mojo::File 'path';
delete $ENV{CONVOS_SECRETS};

my $convos = Convos->new;
is $convos->config->{backend}, 'Convos::Core::Backend::File', 'default backend';
is $convos->config->{home}, $ENV{CONVOS_HOME}, 'home from ENV';
is $convos->config->{organization_name}, 'Convos',           'default organization_name';
is $convos->config->{organization_url},  'http://convos.by', 'default organization_url';
is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
ok !$convos->sessions->secure, 'insecure sessions';
like $convos->secrets->[0], qr/^[a-z0-9]{32}$/, 'default secrets';

my @plugins;
Mojo::Util::monkey_patch(
  Convos => plugin => sub {
    my $self = shift;
    return $self->Mojolicious::plugin(@_) unless $_[0] =~ /Plugin[A-Z\d]/;
    push @plugins, @_;
  }
);

$ENV{CONVOS_PLUGINS}           = 'PluginX';
$ENV{CONVOS_BACKEND}           = 'Convos::Core::Backend';
$ENV{CONVOS_FRONTEND_PID_FILE} = 'pidfile.pid';
$ENV{CONVOS_ORGANIZATION_NAME} = 'cool.org';
$ENV{CONVOS_ORGANIZATION_URL}  = 'http://thorsen.pm';
$ENV{CONVOS_SECRETS}           = 'super,duper,secret';
$ENV{CONVOS_SECURE_COOKIES}    = 1;
delete $ENV{CONVOS_HOME};
$convos = Convos->new;
is $convos->config->{backend},           'Convos::Core::Backend',          'env backend';
like $convos->config->{home},            qr{\W+\.local\W+share\W+convos$}, 'default home';
is $convos->config->{organization_name}, 'cool.org',                       'env organization_name';
is $convos->config->{organization_url},  'http://thorsen.pm',              'env organization_url';
ok $convos->sessions->secure, 'secure sessions';
is_deeply($convos->secrets, [qw(super duper secret)], 'env secrets');
is $plugins[0], 'PluginX', 'PluginX';

delete $ENV{$_} for grep {/CONVOS/} keys %ENV;
$ENV{MOJO_CONFIG} = path->child(qw(t data config.json));
$convos = Convos->new;
is $convos->config->{organization_name}, 'Team JSON',             'json config name';
is $convos->config->{contact},           'mailto:json@localhost', 'json config contact';
is $plugins[6], 'Plugin3', 'Plugin3';

delete $ENV{$_} for grep {/CONVOS/} keys %ENV;
$ENV{MOJO_CONFIG} = path->child(qw(t data config.conf));
$convos = Convos->new;
is $convos->config->{organization_name}, 'Team Perl',             'perl config name';
is $convos->config->{contact},           'mailto:perl@localhost', 'perl config contact';

cmp_deeply(
  \@plugins,
  bag(
    'PluginX' => {},
    'Plugin1' => {config => 'parameter'},
    'Plugin2' => {},
    'Plugin3' => {},
    'Plugin2' => {config => "parameter"},
    'Plugin1' => {},
    'Plugin3' => {},
  ),
  'plugins'
);

done_testing;
