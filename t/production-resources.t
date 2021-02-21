#!perl
use lib '.';
use t::Helper;
use Mojo::File 'curfile';
use Mojo::JSON 'encode_json';

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

SKIP: {
  skip 'BUILD_ASSETS=1 to run "pnpm run build"', 1 unless $ENV{BUILD_ASSETS} or $ENV{RELEASE};
  build_assets();
}

my $t = t::Helper->t;

test_defaults('/' => 200);

$t->get_ok('/')->status_is(200)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"])
  ->content_like(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]);

test_defaults('/err/404' => 404)->element_exists('a.btn[href="/"]')
  ->text_is('title', 'Not Found (404) - Convos')->text_is('h1', 'Not Found (404)');

test_defaults('/err/500' => 500)
  ->element_exists('a[href="https://github.com/convos-chat/convos/issues/"]')
  ->element_exists('a.btn[href="/"]')->text_is('title', 'Internal Server Error (500) - Convos')
  ->text_is('h1', 'Internal Server Error (500)');

done_testing;

sub build_assets {
  opendir(my $ASSETS, 'public/asset');
  /^convos\.[0-9a-f]{8}\.(css|js)\b/ and unlink "public/asset/$_" while $_ = readdir $ASSETS;
  diag qq(\nPlease consult https://convos.chat/doc/develop for details about "pnpm".\n\n)
    unless is system('pnpm run build'), 0, 'run "pnpm run build"';
}

sub test_defaults {
  my ($path, $status) = @_;
  $t->get_ok($path)->status_is($status)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"]);
  $t->content_like(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]) unless $status == 500;
  return $t;
}
