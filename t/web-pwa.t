#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t;
$t->get_ok('/')->status_is(200);

my $n = 0;
$t->tx->res->dom->at('head')->find('[content^="/"], [content^="http"], [href]')->each(sub {
  my $href = $_[0]->{href} || $_[0]->{content};
  $t->get_ok($href)->status_is(200);
  test_browserconfig() if $href =~ m!browserconfig!;
  test_webmanifest()   if $href =~ m!webmanifest!;
  $n++;
});

is $n, 22, 'expected number of head [href]';

done_testing;

sub test_browserconfig {
  subtest 'browserconfig' => sub {
    my $n = 0;
    $t->tx->res->dom->find('[src]')->each(sub {
      $t->get_ok(shift->{src})->status_is(200);
      $n++;
    });

    is $n, 2, 'browserconfig src';
  };
}

sub test_webmanifest {
  subtest 'webmanifest' => sub {
    my $icons       = $t->tx->res->json->{icons};
    my $screenshots = $t->tx->res->json->{screenshots};
    $t->get_ok($_->{src})->status_is(200) for @$icons, @$screenshots;
    is @$icons + @$screenshots, 10, 'icons and screenshots';
  };
}
