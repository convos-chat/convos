#!/usr/bin/perl -n
use Data::Dumper;
use Parse::IRC;
BEGIN { warn "Paste in a line of raw IRC...\n" }
print Dumper parse_irc $_;
