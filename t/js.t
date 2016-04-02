use Test::More;
plan skip_all => "TEST_PHANTOM=1" unless $ENV{TEST_PHANTOM};

my $res = `npm test`;

diag $res;

like($res, qr/TOTAL\: \d+ SUCCESS/, "Success");

done_testing;
