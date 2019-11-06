#!perl
use lib '.';
use t::Helper;
use Mojo::File 'curfile';
use Mojo::JSON 'encode_json';

plan skip_all => 'Skip this test on travis' if $ENV{TRAVIS_BUILD_ID};

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{MOJO_MODE}      = 'production';

SKIP: {
  skip 'BUILD_ASSETS=1 to run "pnpm run build"', 1 unless $ENV{BUILD_ASSETS};
  detect_themes();
  build_assets();
}

my $t = t::Helper->t;

test_defaults('/' => 200);

$t->get_ok('/')->status_is(200)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"])
  ->content_like(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]);

test_defaults('/err/404' => 404)->element_exists('a.btn[href="/"]')
  ->text_is('title', 'Not Found (404)')->text_is('h2', 'Not Found (404)');

test_defaults('/err/500' => 500)
  ->element_exists('a[href="https://github.com/Nordaaker/convos/issues/"]')
  ->element_exists('a.btn[href="/"]')->text_is('title', 'Internal Server Error (500)')
  ->text_is('h2', 'Internal Server Error (500)');

done_testing;

sub build_assets {
  opendir(my $ASSETS, 'public/asset');
  /^convos\.[0-9a-f]{8}\.(css|js)\b/ and unlink "public/asset/$_" while $_ = readdir $ASSETS;
  system 'pnpm run build';
  ok 1, 'pnpm run build';
}

sub detect_themes {
  my @theme_options = (['auto', 'Auto']);
  curfile->dirname->sibling(qw(assets sass themes))->list->each(sub {
    my $theme_file = shift;
    my $fh         = $theme_file->open;
    my ($id, $name) = ('', '');

    while (my $line = readline $fh) {
      $id   = $1 if $line =~ m!html.theme-(\S+)!;
      $name = $1 if $line =~ m!Name:\s*(.+)!;
    }

    $id =~ s!,$!!;
    $name ||= ucfirst $id;

    unless ($id and $name) {
      diag "Theme $theme_file has invalid structure";
      return;
    }

    push @theme_options, [$id => $name];
  });

  my $settings_file = curfile->dirname->sibling(qw(assets settings.js));
  my @settings      = split /\n/, $settings_file->slurp;
  for my $line (@settings) {
    $line = sprintf 'export const themes = %s;', encode_json \@theme_options
      if $line =~ m!export const themes!;
  }

  $settings_file->spurt(join '', map {"$_\n"} @settings);
}

sub test_defaults {
  my ($path, $status) = @_;
  $t->get_ok($path)->status_is($status)->content_like(qr[href="/asset/convos\.[0-9a-f]{8}\.css"])
    ->content_like(qr[src="/asset/convos\.[0-9a-f]{8}\.js"]);
}
