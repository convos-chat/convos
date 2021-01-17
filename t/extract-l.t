use Mojo::Base -strict;
use Mojo::File qw(path);
use Convos::Plugin::I18N;
use List::Util qw(uniq);
use Test::More;

BEGIN { plan skip_all => 'TEST_I18N=1'               unless $ENV{TEST_I18N} }
BEGIN { plan skip_all => 'touch local/capture.po'    unless -r 'local/capture.po' }
BEGIN { plan skip_all => 'Regexp::Common is missing' unless eval 'require Regexp::Common;1' }
plan skip_all => "ack: $!" unless open my $ACK, '-|', q[ack '\b(l|lmd)\(' assets];

use Regexp::Common qw(balanced delimited);
my $l_re = $RE{balanced}{-begin => 'l(|lmd('}{-end => ')}'};
my $q_re = $RE{delimited}{-keep}{-delim => q{'"}};
my ($total, %blacklist, %lexicons) = (0, blacklist());

note 'Locate translations in ./assets/';
while (<$ACK>) {
  next if /\$RE/;    # This file
  next unless my ($file, $line, $text) = /^([^:]+):(\d+):\s*(.+)/;

  while ($text =~ /$l_re/g) {
    my $l_exp = $1;
    while ($l_exp =~ /$q_re/g) {
      next if $blacklist{$3};
      $total++ unless $lexicons{$3};
      $lexicons{$3} ||= {comments => [], msgid => $3, msgstr => $3};
      push @{$lexicons{$3}{comments}}, "$file:$line";
    }
  }
}

note 'Locate translations in ./templates/';
close $ACK;
open $ACK, '-|', q[ack '=l' templates];
$l_re = $RE{balanced}{-begin => '<%=l'}{-end => '%>'};
while (<$ACK>) {
  next if /\$RE/;    # This file
  next unless my ($file, $line, $text) = /^([^:]+):(\d+):\s*(.+)/;

  while ($text =~ /$l_re/g) {
    my $l_exp = $1;
    while ($l_exp =~ /$q_re/g) {
      next if $blacklist{$3};
      $total++ unless $lexicons{$3};
      $lexicons{$3} ||= {comments => [], msgid => $3, msgstr => $3};
      push @{$lexicons{$3}{comments}}, "$file:$line";
    }
  }
}

note 'Captured l() from unit tests';
open my $CAPTURED, '<', 'local/capture.po' or die $!;
while (<$CAPTURED>) {
  next unless my ($file, $line, $msgid) = /^([^:]+):(\d+):(.+)/;
  next if $blacklist{$msgid};
  $total++ unless $lexicons{$msgid};
  $lexicons{$msgid} ||= {comments => [], msgid => $msgid, msgstr => $msgid};
  push @{$lexicons{$3}{comments}}, "$file:$line";
}

note 'Parse existing files in ./assets/i18n';
for my $po_file (path(qw(assets i18n))->list->each) {
  next unless $po_file =~ m!([\w-]+)\.po$!;
  my $lang       = $1;
  my $translated = 0;
  my %has;
  Convos::Plugin::I18N::_parse_po_file(
    $po_file,
    sub {
      my $entry = $_[0];
      return if $blacklist{$entry->{msgid}};
      $has{$entry->{msgid}} = 1;
      $lexicons{$entry->{msgid}} ||= $entry;
      $lexicons{$entry->{msgid}}{msgstr} = $entry->{msgstr};
      $translated++ if $lang eq 'en' or $entry->{msgid} ne $entry->{msgstr};
    },
  );

  open my $PO, '>:encoding(UTF-8)', $po_file or die $!;
  for my $entry (sort { $a->{msgid} cmp $b->{msgid} } values %lexicons) {
    next if $blacklist{$entry->{msgid}};
    $has{$entry->{msgid}} //= 0;
    delete $has{$entry->{msgid}} if $has{$entry->{msgid}};

    if (@{$entry->{comments} || []}) {
      printf $PO qq[#: %s\n], $_ for sort { $a cmp $b } uniq @{$entry->{comments}};
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
  ok $pct > 75, "translated $pct\% in $po_file";
  diag Mojo::Util::dumper(\%has) if %has;
}

done_testing;

sub blacklist {
  return map { ($_ => 1) } (
    '#activeMenu:settings',                       'Nordaaker',
    'base_url',                                   'contact',
    'existing_user',                              'https://convos.chat',
    'https://github.com/nordaaker/convos/issues', 'https://meet.jit.si/',
    'IMG_6322.jpg',                               'IMG_6799.jpg',
    'irc://chat.freenode.net:6697/%%23convos',    'on',
    'organization_name',                          'paste.txt',
    'q',                                          'shift+enter',
    'status',                                     'user@example.com',
    'version',                                    'web-files.t',
    'zyxwvutsrqponmlkjihgfedcba_.txt',
  );
}

sub escape {
  local $_ = "$_[0]";
  s!"!\\"!g;
  return $_;
}
