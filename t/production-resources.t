#!perl
use lib '.';
use t::Helper;

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

unless ($ENV{NO_ROLLUP}) {
  opendir(my $ASSETS, 'public/asset');
  /^convos\.[0-9a-f]{8}\.(css|js)\b/ and unlink "public/asset/$_" while $_ = readdir $ASSETS;
  system 'rollup -c --environment production';
}

my $t = t::Helper->t;

test_defaults('/' => 200);

$t->get_ok('/')->status_is(200)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"])
  ->content_like(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]);

test_defaults('/err/404' => 404)->element_exists('a.btn[href="/"]')
  ->text_is('title', 'Not Found (404)')->text_is('h2', 'Not Found (404)');

test_defaults('/err/500' => 500)
  ->element_exists('a[href="https://github.com/Nordaaker/convos/issues/"]')
  ->element_exists('a.btn[href="/"]')->text_is('title', 'Internal Server Error (500)')
  ->text_is('h2', 'Internal Server Error (500)');

done_testing;

sub test_defaults {
  my ($path, $status) = @_;
  $t->get_ok($path)->status_is($status)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"]);

  my $test_method = $status == 200 ? 'content_like' : 'content_unlike';
  $t->$test_method(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]);
}
