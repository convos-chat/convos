use Test::More;
use Test::Mojo;
use File::Basename qw( basename );
use Mojolicious::Plugin::AssetPack;

{
  my $ap = Mojolicious::Plugin::AssetPack->new;
  $ap->preprocessors->detect;
  plan skip_all => 'Missing preprocessors for scss' unless $ap->preprocessors->has_subscribers('scss');
}

unlink glob 'public/packed/convos-*';
$ENV{MOJO_MODE} = 'production';
my $t = Test::Mojo->new('Convos');
my ($css, $js);

{
  $t->get_ok('/login')->status_is(200)->element_exists(q(link[rel="stylesheet"][href^="/packed/convos-"]))
    ->element_exists(q(script[src^="/packed/convos-"]));

  $css = $t->tx->res->dom->at(q(link[rel="stylesheet"]))->{href};
  $js  = $t->tx->res->dom->at(q(script[src^="/packed/convos-"]))->{src};
  like $css, qr{^/packed/convos-\w+\.css$}, 'got production convos.css';
  like $js,  qr{^/packed/convos-\w+\.js$},  'got production convos.js';
}

SKIP: {
  my $packed = './public/packed';

  $t->get_ok($css)->status_is(200);
  -d $packed or skip "Cannot look into $packed", 3;
  opendir(my $PACKED, $packed);

  my @packed = map { $_->[0] }
    sort { $a->[1] cmp $b->[1] } grep { $_->[1] } map { /convos-\w+\.(css|js)$/; [$_, $1] } readdir $PACKED;

  is $packed[0], basename($css), 'found convos.css file';
  is $packed[1], basename($js),  'found convos.js file';
}

{
  open my $FH, 'lib/Convos.pm' or skip 'Cannot read lib/Convos.pm', 1;
  my ($version_scalar, $version_pod, $head) = ('s', 'p');

  while (<$FH>) {
    $head           = $1     if /^=head1 (\w+)/;
    $version_scalar = $1 + 0 if /VERSION\s*=\s*'(\S+)';/;
    $version_pod = $1 + 0 if $head eq 'VERSION' and /^([\d\.]+)/;
  }

  is $version_scalar, $version_pod, 'VERSION match';
}

done_testing;
