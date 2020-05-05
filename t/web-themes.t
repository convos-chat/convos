#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t;

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
        default => '/themes/convos_color-scheme-light.css',
        dark    => '/themes/convos_color-scheme-dark.css',
        light   => '/themes/convos_color-scheme-light.css'
      },
    },
    desert  => {name => 'Desert',  variants => {default => '/themes/desert.css'}},
    mytheme => {name => 'MyTheme', variants => {default => '/themes/MyTheme.css'}},
    nord    => {name => 'Nord',    variants => {default => '/themes/nord.css'}},
  },
  'default themes',
) or diag explain $t->app->defaults('themes');

$t->get_ok('/themes/MyTheme.css')->status_is(200)->content_like(qr{custom theme});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});

$t->get_ok('/')->status_is(200)
  ->element_exists('link[href="/themes/convos_color-scheme-light.css"]');
$t->get_ok('/', {Cookie => js_session(colorScheme => 'dark')})->status_is(200)
  ->element_exists('link[href="/themes/convos_color-scheme-dark.css"]');
$t->get_ok('/', {Cookie => js_session(colorScheme => 'dark', theme => 'nord')})->status_is(200)
  ->element_exists('link[href="/themes/nord.css"]');

done_testing;

sub js_session {
  return sprintf 'convos_js=%s', Mojo::Util::b64_encode(Mojo::JSON::encode_json({@_}), '');
}
