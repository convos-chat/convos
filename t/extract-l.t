use Mojo::Base -strict;
use Mojo::File qw(path);
use Convos::Plugin::I18N;
use Test::More;

BEGIN { plan skip_all => 'TEST_I18N=1'               unless $ENV{TEST_I18N} }
BEGIN { plan skip_all => 'Regexp::Common is missing' unless eval 'require Regexp::Common;1' }
plan skip_all => "ack: $!" unless open my $ACK, '-|', q[ack '\b(l|lmd)\(' assets];

use Regexp::Common qw(balanced delimited);
my $l_re = $RE{balanced}{-begin => 'l(|lmd('}{-end => ')}'};
my $q_re = $RE{delimited}{-keep}{-delim => q{'"}};

my ($total, %lexicons) = (0);
while (<$ACK>) {
  next if /\$RE/;    # This file
  next unless my ($file, $line, $text) = /^([^:]+):(\d+):\s*(.+)/;

  while ($text =~ /$l_re/g) {
    my $l_exp = $1;
    while ($l_exp =~ /$q_re/g) {
      $total++ unless $lexicons{$3};
      $lexicons{$3} ||= {comments => [], msgid => $3, msgstr => $3};
      push @{$lexicons{$3}{comments}}, "$file:$line";
    }
  }
}

for my $po_file (path(qw(assets i18n))->list->each) {
  next unless $po_file =~ m!([\w-]+)\.po$!;
  my $lang       = $1;
  my $translated = 0;
  Convos::Plugin::I18N::_parse_po_file(
    $po_file,
    sub {
      my $entry = $_[0];
      $lexicons{$entry->{msgid}} ||= $entry;
      $lexicons{$entry->{msgid}}{msgstr} = $entry->{msgstr};
      $translated++ if $lang eq 'en' or $entry->{msgid} ne $entry->{msgstr};
    },
  );

  open my $PO, '>:encoding(UTF-8)', $po_file or die $!;
  for my $entry (sort { $a->{msgid} cmp $b->{msgid} } values %lexicons) {
    if (@{$entry->{comments} || []}) {
      printf $PO qq[#: %s\n], $_ for sort @{$entry->{comments}};
    }
    else {
      note "Translation ($entry->{msgid}) not found.";
      $translated--;
    }
    printf $PO qq[msgid "%s"\n],    escape($entry->{msgid});
    printf $PO qq[msgstr "%s"\n\n], escape($entry->{msgstr});
  }

  my $pct = int($translated / $total * 100);
  ok %lexicons, "found $translated/$total lexicons in $po_file";
  ok $pct > 70, "translated $pct\% in $po_file";
}

done_testing;

sub escape {
  local $_ = "$_[0]";
  s!"!\\"!g;
  return $_;
}
