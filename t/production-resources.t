use lib '.';
use t::Helper;

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

my $t = t::Helper->t;

$t->get_ok('/')->content_like(qr{mode:\s*"production"})
  ->element_exists('head link[href$="/convos.css"]')
  ->element_exists('body script[src$="/convos.js"]');

$t->get_ok('/err/404')->status_is(404)->element_exists_not('script')
  ->element_exists('head link[href$="/convos.css"]')->element_exists('a.btn[href="/"]')
  ->text_is('title', 'Not Found (404)')->text_is('h2', 'Not Found (404)');

$t->get_ok('/err/500')->status_is(500)->element_exists_not('script')
  ->element_exists('head link[href$="/convos.css"]')
  ->element_exists('a[href="https://github.com/Nordaaker/convos/issues/"]')
  ->element_exists('a.btn[href="/"]')->text_is('title', 'Internal Server Error (500)')
  ->text_is('h2', 'Internal Server Error (500)');

done_testing;
