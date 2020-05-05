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
      name          => 'Convos',
      color_schemes => {
        default => 'convos_color-scheme-light.css',
        dark    => 'convos_color-scheme-dark.css',
        light   => 'convos_color-scheme-light.css'
      },
    },
    desert  => {name => 'Desert',  color_schemes => {default => 'desert.css'}},
    mytheme => {name => 'MyTheme', color_schemes => {default => 'MyTheme.css'}},
    nord    => {name => 'Nord',    color_schemes => {default => 'nord.css'}},
  },
  'default themes',
) or diag explain $t->app->defaults('themes');

$t->get_ok('/themes/MyTheme.css')->status_is(200)->content_like(qr{custom theme});
$t->get_ok('/themes/nope.css')->status_is(404)->content_like(qr{nope\.css not found});

done_testing;
