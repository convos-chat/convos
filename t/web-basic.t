#!perl
use lib '.';
use t::Helper;

plan skip_all => '$ NODE_ENV=development pnpm run build'
  unless -e 'public/asset/webpack.development.html';

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'development';

my $t       = t::Helper->t->get_ok('/');
my $image   = '/images/2020-05-28-convos-chat.jpg';
my $og_url  = $t->ua->server->url;
my $version = Convos->VERSION;

$t->text_is('title', 'Better group chat - Convos')
  ->element_exists(
  qq(meta[name="viewport"][content="width=device-width, initial-scale=1, maximum-scale=1"]))
  ->element_exists(qq(meta[name="apple-mobile-web-app-capable"][content="yes"]))
  ->element_exists(qq(meta[name="contactnetworkaddress"][content="https://convos.chat"]))
  ->element_exists(qq(meta[name="contactorganization"][content="Convos"]))
  ->element_exists(qq(meta[name="convos:base_url"][content^="http://"]))
  ->element_exists(qq(meta[name="convos:contact"][content="bWFpbHRvOnJvb3RAbG9jYWxob3N0"]))
  ->element_exists(qq(meta[name="convos:existing_user"][content="no"]))
  ->element_exists(qq(meta[name="convos:first_user"][content="yes"]))
  ->element_exists(qq(meta[name="convos:open_to_public"][content="no"]))
  ->element_exists(qq(meta[name="convos:start_app"][content="chat"]))
  ->element_exists(qq(meta[name="convos:status"][content="200"]))
  ->element_exists(qq(meta[name="description"][content^="A chat application"]))
  ->element_exists(qq(meta[name="twitter:card"][content="summary"]))
  ->element_exists(qq(meta[name="twitter:description"][content^="A chat application"]))
  ->element_exists(qq(meta[name="twitter:image:src"][content\$="$image"]))
  ->element_exists(qq(meta[name="twitter:site"][content="\@convosby"]))
  ->element_exists(qq(meta[name="twitter:title"][content="Better group chat"]))
  ->element_exists(qq(meta[property="og:description"][content^="A chat application"]))
  ->element_exists(qq(meta[property="og:image"][content\$="$image"]))
  ->element_exists(qq(meta[property="og:site_name"][content="Convos"]))
  ->element_exists(qq(meta[property="og:title"][content="Better group chat"]))
  ->element_exists(qq(meta[property="og:type"][content="object"]))
  ->element_exists(qq(meta[property="og:url"][content="$og_url"]))
  ->element_exists(qq(meta[name="version"][content="$version"]))->element_exists(qq(body.for-cms));

$t->text_like('noscript p', qr{javascript}i);
$t->text_is('a[href="https://convos.chat/blog"]', 'Blog');

unless ($ENV{TRAVIS_BUILD_ID}) {
  $t->element_exists('link[rel="stylesheet"]')->element_exists('script');
}

$ENV{CONVOS_ORGANIZATION_NAME} = 'Example';
$ENV{CONVOS_ORGANIZATION_URL}  = 'http://example.com';

$t = t::Helper->t->get_ok('/');
$t->text_is('title', 'Better group chat - Convos for Example')
  ->element_exists(qq(meta[name="twitter:title"][content="Better group chat"]))
  ->element_exists(qq(meta[property="og:site_name"][content="Example"]))
  ->element_exists(qq(meta[property="og:title"][content="Better group chat"]));

$t->text_is('.hero a[href="http://example.com"]', 'for Example');
$t->get_ok($image)->status_is(200);

done_testing;
