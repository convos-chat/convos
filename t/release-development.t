use Test::More;
use Test::Mojo;
use File::Basename qw( basename );
use Mojolicious::Plugin::AssetPack;

plan skip_all => 'Currently broken';
{
  my $ap = Mojolicious::Plugin::AssetPack->new;
  $ap->preprocessors->detect;
  plan skip_all => 'Missing preprocessors for scss' unless $ap->preprocessors->has_subscribers('scss');
}

unlink glob 'public/packed/main-*';
$ENV{MOJO_MODE} = 'testing';
my $t = Test::Mojo->new('Convos');
my $css;

{
  $t->get_ok('/login')->status_is(200)->element_exists(q(link[rel="stylesheet"][href^="/packed/main-"]));

  $css = $t->tx->res->dom->at(q(link[rel="stylesheet"]))->{href};
  like $css, qr{^/packed/main-\w+\.css$}, 'got production convos.css';
}

SKIP: {
  my $packed = './public/packed';
  $t->get_ok($css)->status_is(200);
  -d $packed or skip "Cannot look into $packed", 2;
  opendir(my $PACKED, $packed);
  my @packed = sort grep {/main-\w+\.css$/} readdir $PACKED;
  is $packed[0], basename($css), 'found main.css file';
  is @packed, 1, 'found one packed convos file';
}

done_testing;
