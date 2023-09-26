#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t;
my $v = $t->app->VERSION;

my $user_themes = Mojo::File->new($t->app->config('home'), 'themes');
$user_themes->child('README.md')->spew("# skip this\n");
$user_themes->child('MyTheme.css')->spew("/* custom theme */");
$t->app->themes->detect;

$t->get_ok('/')->status_is(200)->element_exists('link[id$="dark-convos"][title="Convos (dark)"]')
  ->element_exists('link[id$="dark-high-contrast"][title="High-contrast (dark)"]')
  ->element_exists('link[id$="dark-nord"][title="Nord (dark)"]')
  ->element_exists('link[id$="light-convos"][title="Convos (light)"]')
  ->element_exists('link[id$="light-high-contrast"][title="High-contrast (light)"]')
  ->element_exists('link[id$="light-nord"][title="Nord (light)"]')
  ->element_exists('link[id$="normal-desert"][title="Desert"]')
  ->element_exists('link[id$="normal-south"][title="South"]')
  ->element_exists('link[id$="normal-hacker"][title="Hacker"]')
  ->element_exists('link[id$="normal-mytheme"][title="MyTheme"]');

for my $id (qw(theme_alt__dark- theme_alt__light- theme_alt__normal-)) {
  my $els = $t->tx->res->dom(
    qq(link[rel="alternate stylesheet"][id^="$id"][type="text/css"][href^="/themes/"]));
  ok $els->size >= 3, "found $id";
}

$t->get_ok('/themes/MyTheme.css')->status_is(200)->content_like(qr{custom theme});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});

$t->get_ok('/register?first=1')->status_is(200)
  ->element_exists(qq(link[href="/themes/convos_color-scheme-light.css?v=$v"]));
$t->get_ok('/register?first=1', {Cookie => js_session(colorScheme => 'dark', theme => 'convos')})
  ->status_is(200)->element_exists(qq(link[href="/themes/convos_color-scheme-dark.css?v=$v"]));
$t->get_ok('/register?first=1', {Cookie => js_session(colorScheme => 'dark', theme => 'nord')})
  ->status_is(200)->element_exists(qq(link[href="/themes/nord_color-scheme-dark.css?v=$v"]));

done_testing;

sub js_session {
  return sprintf 'convos_js=%s', Mojo::Util::b64_encode(Mojo::JSON::encode_json({@_}), '');
}
