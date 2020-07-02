#!perl
use Mojo::Base -strict;
use File::Basename 'basename';
use Mojo::JSON 'encode_json';
use Test::More;

BEGIN {
  plan skip_all => 'BUILD_ASSETS=1'            unless $ENV{BUILD_ASSETS};
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

opendir my $I18N, 'assets/i18n';
for my $po_file (map {"assets/i18n/$_"} readdir $I18N) {
  next unless $po_file =~ /\.po$/;
  open my $PO, '<', $po_file or die $!;
  my %entry;

  while (<$PO>) {
    @entry{qr{file line}} = ($1, $2)    if /^#:\s*([^:]+):(\d+)/;
    $entry{$1}            = unquote($2) if /(msgid|msgstr)\s*(['"].*)/;

    if (defined $entry{msgsid} and defined $entry{msgstr}) {
      $lexicons{$entry{msgid}} ||= {%entry};
      $lexicons{$entry{msgid}}{msgstr} = $entry{msgstr};
      %entry = ();
    }
  }

  close $PO;
  open $PO, '>', $po_file or die $!;
  for my $entry (sort { $a->{msgid} cmp $b->{msgid} } values %lexicons) {
    printf $PO qq[#: %s:%s\n],      @$entry{qw(file line)};
    printf $PO qq[msgid "%s"\n],    escape_quote($entry->{msgid});
    printf $PO qq[msgstr "%s"\n\n], escape_quote($entry->{msgstr});
  }

  my $json_file = $po_file;
  $json_file =~ s!assets!public!;
  $json_file =~ s!\.po$!.json!;
  open $PO, '>', $json_file or die $!;
  print $PO encode_json {
    map { ($_->{msgid} => $_->{msgstr}) } values %lexicons
  };
}

ok %lexicons, 'found lexicons';

done_testing;

sub escape_quote {
  local $_ = $_[0];
  s!"!\\"!g;
  return $_;
}

sub unquote {
  local $_ = $_[0];
  s!^['"]!! and s!['"]$!!;
  return $_;
}
