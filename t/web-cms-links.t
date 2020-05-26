#!perl
use lib '.';
use t::Helper ();
use Mojo::Base -strict;
use Test::More;

plan skip_all => 'CONVOS_HOME=$HOME/.local/share/convos' unless $ENV{CONVOS_HOME};

$ENV{MOJO_MODE} = 'production';
my $t = t::Helper->t;

my (@url, %uniq) = ($ENV{TEST_CMS_START_PAGE} || '/');
while (@url) {
  $t->get_ok(shift @url)->status_is(200);
  push @url,
    grep { !$uniq{$_}++ } map { $_->{href} || $_->{src} } $t->tx->res->dom('[href^="/"]')->each,
    $t->tx->res->dom('[src^="/"]')->each;
  last unless @url;
}

done_testing;
