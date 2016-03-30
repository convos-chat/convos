#!/usr/bin/env perl
use Mojo::Base -strict;
use Data::Dumper;
use Parse::IRC 'parse_irc';
use IRC::Utils 'numeric_to_name';

warn "Paste in an IRC message.\n" if -t STDIN;
local $Data::Dumper::Indent   = 1;
local $Data::Dumper::Terse    = 1;
local $Data::Dumper::Sortkeys = 1;

while (<STDIN>) {
  warn "<<< $_";
  my $msg = parse_irc($_ || '') || {};
  next unless $msg->{command};
  $msg->{event} = numeric_to_name($msg->{command}) || $msg->{command} if $msg->{command} =~ /^\d+$/;
  $msg->{event} = lc $msg->{event};
  print Dumper($msg);
}
