use Mojo::Base -strict;
use Mojo::File qw(path);
use Convos::Plugin::I18N;
use Test::More;

BEGIN {
  plan skip_all => 'TEST_I18N=1'               unless $ENV{TEST_I18N};
  plan skip_all => 'Regexp::Common is missing' unless eval 'require Regexp::Common;1';
}

use Regexp::Common qw(balanced delimited);
my $l_re = $RE{balanced}{-keep}{-begin => '{l('}{-end => ')}'};
my $q_re = $RE{delimited}{-keep}{-delim => q{'"}};

plan skip_all => "ack: $!" unless open my $ACK, '-|', q[ack '\bl\(' assets];
my %lexicons;
while (<$ACK>) {
  next if /\$RE/;    # This file
  next unless my ($file, $line, $text) = /^([^:]+):(\d+):\s*(.+)/;

  my ($n, @f) = (0);
  while ($text =~ /$l_re/g) {
    my $l_exp = $1;
    $n++;

    while ($l_exp =~ /$q_re/g) {
      push @f, $3;
      $lexicons{$3} = {file => $file, line => $line, msgid => $3, msgstr => $3};
    }
  }
}

for my $po_file (path(qw(assets i18n))->list->each) {
  next unless $po_file =~ /\.po$/;
  Convos::Plugin::I18N::_parse_po_file(
    $po_file,
    sub {
      my $entry = $_[0];
      $lexicons{$entry->{msgid}} ||= $entry;
      $lexicons{$entry->{msgid}}{msgstr} = $entry->{msgstr};
    },
  );

  open my $PO, '>', $po_file or die $!;
  for my $entry (sort { $a->{msgid} cmp $b->{msgid} } values %lexicons) {
    printf $PO qq[#: %s:%s\n],      @$entry{qw(file line)};
    printf $PO qq[msgid "%s"\n],    escape_quote($entry->{msgid});
    printf $PO qq[msgstr "%s"\n\n], escape_quote($entry->{msgstr});
  }

  ok %lexicons, "found lexicons in $po_file";
}

done_testing;

sub escape_quote {
  local $_ = $_[0];
  s!"!\\"!g;
  return $_;
}
