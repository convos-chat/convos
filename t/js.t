use Test::More;
plan skip_all => "TEST_PHANTOM=1" unless $ENV{TEST_PHANTOM};


use File::Basename;
@files = <templates/vue/*.html.ep>;
foreach $file (@files) {
  my $basefile = basename($file);
  $basefile =~ s/\.html\.ep$/\.vue/;
  symlink('../../' . $file, "src/components/" . $basefile);
}

my $res = `npm test`;
diag $res;
like($res, qr/TOTAL\: \d+ SUCCESS/, "Success");

done_testing;
