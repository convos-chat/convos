use Mojo::Base -strict;
use Mojolicious::Plugin::AssetPack;
use File::Basename qw( basename );
use Test::More;
use Test::Mojo;

plan skip_all => 'Can only run on linux' unless $^O eq 'linux';

$ENV{CONVOS_REDIS_URL} = 'redis://invalid-host.localhost';
$ENV{MOJO_MODE}        = 'production';

{
  my $ap = Mojolicious::Plugin::AssetPack->new;
  $ap->preprocessors->detect;
  plan skip_all => 'Missing preprocessors for scss' unless $ap->preprocessors->has_subscribers('scss');
}

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

SKIP: {
  my $packed = 'public/packed';

  $t->get_ok($css)->status_is(200);
  -d $packed or skip "Cannot look into $packed", 3;
  opendir(my $PACKED, $packed);

  my @packed
    = map { $_->[0] }
    sort { $b->[2][9] <=> $a->[2][9] || $a->[1] cmp $b->[1] }
    grep { $_->[1] } map { /c-\w+\.(css|js)$/; [$_, $1, [stat "$packed/$_"]] } readdir $PACKED;

  is $packed[0], basename($css), 'found c.css file';
  is $packed[1], basename($js),  'found c.js file';
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
