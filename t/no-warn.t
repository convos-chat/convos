use strict;
use warnings;
use Test::More;
use File::Find;

find(
  sub {
    my $file = $_;
    return unless -f $file;
    open my $FH, '<', $file or die "open $file: $!";
    while (<$FH>) {
      if (/ \bwarn\b/ and !/DEBUG;/) {
        chomp;
        BAIL_OUT "$File::Find::name\:$.\: Cannot contain ($_)";
      }
    }
  },
  'lib',
);

ok 1, 'no warn() in code \o/';
done_testing;
