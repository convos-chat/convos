#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t;
my $v = $t->app->VERSION;

my $user_themes = Mojo::File->new($t->app->config('home'), 'themes');
$user_themes->child('README.md')->spurt("# skip this\n");
$user_themes->child('MyTheme.css')->spurt("/* custom theme */");
$t->app->_detect_themes;

is_deeply(
  $t->app->defaults('themes'),
  {
    convos => {
      name     => 'Convos',
      variants => {
        default => qq(/themes/convos_color-scheme-light.css?v=$v),
        dark    => qq(/themes/convos_color-scheme-dark.css?v=$v),
        light   => qq(/themes/convos_color-scheme-light.css?v=$v),
      },
    },
    'high-contrast' => {
      name     => 'High-contrast',
      variants => {
        default => qq(/themes/high-contrast_color-scheme-light.css?v=$v),
        dark    => qq(/themes/high-contrast_color-scheme-dark.css?v=$v),
        light   => qq(/themes/high-contrast_color-scheme-light.css?v=$v),
      },
    },
    desert  => {name => 'Desert',  variants => {default => qq(/themes/desert.css?v=$v)}},
    mytheme => {name => 'MyTheme', variants => {default => qq(/themes/MyTheme.css?v=$v)}},
    nord    => {name => 'Nord',    variants => {default => qq(/themes/nord.css?v=$v)}},
  },
  'default themes',
) or diag explain $t->app->defaults('themes');

$t->get_ok('/themes/MyTheme.css')->status_is(200)->content_like(qr{custom theme});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/themes/convos_color-scheme-light.css?v=$v"]));
$t->get_ok('/', {Cookie => js_session(colorScheme => 'dark')})->status_is(200)
  ->element_exists(qq(link[href="/themes/convos_color-scheme-dark.css?v=$v"]));
$t->get_ok('/', {Cookie => js_session(colorScheme => 'dark', theme => 'nord')})->status_is(200)
  ->element_exists(qq(link[href="/themes/nord.css?v=$v"]));

done_testing;

sub js_session {
  return sprintf 'convos_js=%s', Mojo::Util::b64_encode(Mojo::JSON::encode_json({@_}), '');
}
