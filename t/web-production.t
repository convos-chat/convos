#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

my $t = t::Helper->t;
$t->get_ok('/')->status_is(200)->header_is('Content-Security-Policy', q(block-all-mixed-content; base-uri 'self'; connect-src 'self'; frame-ancestors 'none'; manifest-src 'self'; default-src 'none'; font-src 'self'; frame-src 'self'; img-src *; object-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';));

done_testing;
