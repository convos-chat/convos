#!perl
use lib '.';
use t::Helper;

plan skip_all => '$ NODE_ENV=development pnpm run build'
  unless -e 'public/asset/webpack.development.html';

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'development';

my $t     = t::Helper->t->get_ok('/');
my $url   = $t->ua->server->url;
my $image = 'https://convos.by/public/screenshots/2016-09-01-participants.png';

$t->content_like(qr{window.__convos\s*=})->text_is('title', 'Convos - Better group chat')
  ->element_exists(
  qq(meta[name="viewport"][content="width=device-width, initial-scale=1, maximum-scale=1"]))
  ->element_exists(qq(meta[name="apple-mobile-web-app-capable"][content="yes"]))
  ->element_exists(qq(meta[name="description"]))
  ->element_exists(qq(meta[name="twitter:card"][content="summary"]))
  ->element_exists(qq(meta[name="twitter:description"]))
  ->element_exists(qq(meta[name="twitter:image:src"][content="$image"]))
  ->element_exists(qq(meta[name="twitter:site"][content="\@convosby"]))
  ->element_exists(qq(meta[name="twitter:title"][content="Convos - Better group chat"]))
  ->element_exists(qq(meta[property="og:type"][content="object"]))
  ->element_exists(qq(meta[property="og:description"]))
  ->element_exists(qq(meta[property="og:image"][content="$image"]))
  ->element_exists(qq(meta[property="og:site_name"][content="Convos"]))
  ->element_exists(qq(meta[property="og:title"][content="Convos - Better group chat"]))
  ->element_exists(qq(meta[property="og:url"][content="$url"]));

$t->text_like('noscript p', qr{javascript}i);
$t->text_is('a[href="https://convos.by/doc"]', 'Documentation');

$t->text_like('script', qr{"apiUrl":"\\/api"}m,      'apiUrl')
  ->text_like('script', qr{"wsUrl":"ws:.*/events"}m, 'wsUrl')
  ->text_like('script', qr{"invite_code":\s*true}m,  'invite_code');

unless ($ENV{TRAVIS_BUILD_ID}) {
  $t->element_exists('link[rel="stylesheet"]')->element_exists('script');
}

$ENV{CONVOS_INVITE_CODE}       = '';
$ENV{CONVOS_ORGANIZATION_NAME} = 'Example';
$ENV{CONVOS_ORGANIZATION_URL}  = 'http://example.com';

$t = t::Helper->t->get_ok('/');
$t->content_like(qr{window.__convos\s*=})->text_is('title', 'Convos for Example')
  ->element_exists(qq(meta[name="twitter:title"][content="Convos for Example"]))
  ->element_exists(qq(meta[property="og:site_name"][content="Example"]))
  ->element_exists(qq(meta[property="og:title"][content="Convos for Example"]));

$t->text_is('a[href="http://example.com"]', 'Example');

$t->text_like('script', qr{"invite_code":\s*false}m, 'invite_code');

SKIP: {
  skip 'TEST_ONLINE=1 must be set', 2 unless $ENV{TEST_ONLINE} or $ENV{TRAVIS_BUILD_ID};
  $t->head_ok($image)->status_is(200);
}

done_testing;
