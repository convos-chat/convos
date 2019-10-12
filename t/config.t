#!perl
use lib '.';
use t::Helper;
use Mojo::File 'path';
delete $ENV{CONVOS_SECRETS};

my $i      = 0;
my $convos = Convos->new;
my $secret = $convos->secrets->[0];

is $convos->config->{backend}, 'Convos::Core::Backend::File', 'default backend';
is $convos->config->{default_connection}, 'irc://chat.freenode.net:6697/%23convos',
  'default default_connection';
is $convos->config->{home}, $ENV{CONVOS_HOME}, 'home from ENV';
is $convos->config->{organization_name}, 'Convos',           'default organization_name';
is $convos->config->{organization_url},  'http://convos.by', 'default organization_url';
is $convos->config->{hypnotoad}{pid_file}, undef, 'default pid_file';
ok !$convos->sessions->secure, 'insecure sessions';
like $convos->config->{invite_code}, qr/^\w{32}$/, 'generated invite_code';
like $secret, qr/^[a-z0-9]{40}$/, 'default secrets';

is(Convos->new->secrets->[0], $secret, 'reusing generated secret');

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
$ENV{CONVOS_DEFAULT_SERVER}    = 'irc.example.com';
$ENV{CONVOS_FRONTEND_PID_FILE} = 'pidfile.pid';
$ENV{CONVOS_ORGANIZATION_NAME} = 'cool.org';
$ENV{CONVOS_ORGANIZATION_URL}  = 'http://thorsen.pm';
$ENV{CONVOS_SECRETS}           = 'super,duper,secret';
$ENV{CONVOS_SECURE_COOKIES}    = 1;
delete $ENV{CONVOS_HOME};
$i++;
$convos = Convos->new;
is $convos->config->{backend}, 'Convos::Core::Backend',          'env backend';
like $convos->config->{home},  qr{\W+\.local\W+share\W+convos$}, 'default home';
is $convos->config->{default_connection}, 'irc://irc.example.com', 'env default_connection';
is $convos->config->{forced_irc_server},  0,                       'default forced_irc_server';
is $convos->config->{organization_name},  'cool.org',              'env organization_name';
is $convos->config->{organization_url},   'http://thorsen.pm',     'env organization_url';
ok $convos->sessions->secure, 'secure sessions';
is_deeply($convos->secrets, [qw(super duper secret)], 'env secrets');
is $plugins[1], 'PluginX', 'PluginX';

delete $ENV{$_} for grep {/CONVOS/} keys %ENV;
$ENV{MOJO_CONFIG} = path->child(qw(t data config.json));
$i++;
$convos = Convos->new;
is $convos->config->{organization_name}, 'Team JSON',             'json config name';
is $convos->config->{contact},           'mailto:json@localhost', 'json config contact';
is $convos->config->{invite_code},       'json_example',          'invite_code from config file';
is_deeply($convos->secrets, [qw(signed-json-secret)], 'config secrets');
is $plugins[10], 'Plugin3', 'Plugin3';

delete $ENV{$_} for grep {/CONVOS/} keys %ENV;
$ENV{MOJO_CONFIG} = path->child(qw(t data config.conf));
$i++;
$convos = Convos->new;
is $convos->config->{organization_name}, 'Team Perl',             'perl config name';
is $convos->config->{contact},           'mailto:perl@localhost', 'perl config contact';

cmp_deeply(
  \@plugins,
  bag(
    1,
    'PluginX' => superhashof({organization_url => 'http://thorsen.pm'}),
    2,
    'Plugin1' => {config => 'parameter'},
    2,
    'Plugin2' => superhashof({organization_url => 'http://convos.by'}),
    2,
    'Plugin3' => superhashof({organization_url => 'http://convos.by'}),
    3,
    'Plugin1' => {},
    3,
    'Plugin2' => {config => "parameter"},
    3, 'Plugin3' => {},
  ),
  'plugins'
) or diag Data::Dumper::Dumper(\@plugins);

delete $ENV{MOJO_CONFIG};
$ENV{CONVOS_FORCED_IRC_SERVER} = 'irc://localhost:1234/%23cool_channel';
$convos = Convos->new;
is $convos->config->{default_connection}, 'irc://localhost:1234/%23cool_channel',
  'forced default_connection';
is $convos->config->{forced_irc_server}, 1, 'env forced_irc_server';
is $convos->config->{settings}{forced_irc_server}, true, 'settings forced_irc_server';

done_testing;
