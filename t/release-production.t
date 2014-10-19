use Mojo::Base -strict;
use Mojolicious::Plugin::AssetPack;
use File::Basename qw( basename );
use Test::More;
use Test::Mojo;

plan skip_all => 'Can only run on linux' unless $^O eq 'linux';

$ENV{CONVOS_REDIS_URL} = 'redis://invalid-host.localhost';
$ENV{MOJO_MODE}        = 'production';

my $ap = Mojolicious::Plugin::AssetPack->new;
plan skip_all => 'Missing preprocessors for scss' unless $ap->preprocessors->can_process('scss');

my $t = Test::Mojo->new('Convos');
my ($css, $js);

$t->app->config(redis_version => 1, hostname_is_set => 1);

{
  $t->get_ok('/login')->status_is(200)->element_exists(q(link[rel="stylesheet"][href^="/packed/c-"]))
    ->element_exists(q(script[src^="/packed/c-"]));

  $css = $t->tx->res->dom->at(q(link[rel="stylesheet"]))->{href};
  $js  = $t->tx->res->dom->at(q(script[src^="/packed/c-"]))->{src};
  like $css, qr{^/packed/c-\w+\.css$}, 'got production c.css';
  like $js,  qr{^/packed/c-\w+\.js$},  'got production c.js';
}

{
  open my $FH, 'lib/Convos.pm' or skip 'Cannot read lib/Convos.pm', 1;
  my ($version_scalar, $version_pod, $head) = ('s', 'p', '');

  while (<$FH>) {
    $head           = $1     if /^=head1 (\w+)/;
    $version_scalar = $1 + 0 if /VERSION\s*=\s*'(\S+)';/;
    $version_pod = $1 + 0 if $head eq 'VERSION' and /^([\d\.]+)/;
  }

  is $version_scalar, $version_pod, 'VERSION from Convos.pm match in code and pod';
}

done_testing;
