#!/usr/bin/perl -n
use Data::Dumper;
use Parse::IRC;
use IRC::Utils;
BEGIN { warn "Paste in a line of raw IRC...\n" }
my $d = parse_irc($_);
$d->{'command_name'} = IRC::Utils::numeric_to_name($d->{'command'}) || '';
$d->{'command_name_lc'} = lc(IRC::Utils::numeric_to_name($d->{'command'}) || '');
print Dumper($d);
