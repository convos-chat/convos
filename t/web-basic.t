use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'development';

my $t     = t::Helper->t->get_ok('/');
my $url   = $t->ua->server->url;
my $image = 'https://convos.by/public/screenshots/2016-09-01-participants.png';

$t->content_like(qr{mode:\s*"development"})
  ->element_exists(
  qq(meta[name="viewport"][content="width=device-width, initial-scale=1, maximum-scale=1"]))
  ->element_exists(qq(meta[name="apple-mobile-web-app-capable"][content="yes"]))
  ->element_exists(qq(meta[name="description"]))
  ->element_exists(qq(meta[name="twitter:card"][content="summary"]))
  ->element_exists(qq(meta[name="twitter:description"]))
  ->element_exists(qq(meta[name="twitter:image:src"][content="$image"]))
  ->element_exists(qq(meta[name="twitter:site"][content="\@convosby"]))
  ->element_exists(qq(meta[name="twitter:title"][content="Convos for Nordaaker"]))
  ->element_exists(qq(meta[property="og:type"][content="object"]))
  ->element_exists(qq(meta[property="og:description"]))
  ->element_exists(qq(meta[property="og:image"][content="$image"]))
  ->element_exists(qq(meta[property="og:site_name"][content="Convos"]))
  ->element_exists(qq(meta[property="og:title"][content="Convos for Nordaaker"]))
  ->element_exists(qq(meta[property="og:url"][content="$url"]));

$t->text_like('noscript p', qr{javascript}i);
$t->text_is('a[href="http://convos.by"]',     'About');
$t->text_is('a[href="http://nordaaker.com"]', 'Nordaaker');

SKIP: {
  skip 'TEST_ONLINE=1 must be set', 2 unless $ENV{TEST_ONLINE} or $ENV{TRAVIS_BUILD_ID};
  $t->head_ok($image)->status_is(200);
}

done_testing;
