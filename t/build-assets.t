use lib '.';
use t::Helper;

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

my $t = t::Helper->t;

$t->get_ok('/')->content_like(qr{mode:\s*"production"})
  ->element_exists('head link[href$="/convos.css"]')
  ->element_exists('body script[src$="/convos.js"]');

done_testing;
