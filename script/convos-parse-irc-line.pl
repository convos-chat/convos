#!/usr/bin/env perl -n
use Data::Dumper;
use Parse::IRC;
use IRC::Utils;
BEGIN { warn "Paste in a line of raw IRC...\n" }
my $d = parse_irc($_);
$d->{command_name} = IRC::Utils::numeric_to_name($d->{command}) || '';
$d->{command_name_lc} = lc(IRC::Utils::numeric_to_name($d->{command}) || '');
local $Data::Dumper::Indent   = 1;
local $Data::Dumper::Sortkeys = 1;
local $Data::Dumper::Terse    = 1;
print Dumper($d);
