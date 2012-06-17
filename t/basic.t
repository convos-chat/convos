use Mojo::Base -strict;

use Test::More tests => 3;
use Test::Mojo;

my $t = Test::Mojo->new('WebIrc');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
