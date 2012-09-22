package WebIrc::Core::Util;

=head1 NAME

WebIrc::Core::Util - Utility functions for WebIrc

=head1 SYNOPSIS

  use WebIrc::Core::Util qw/ pack_msg ... /;

L</import> can export any of the L</FUNCTIONS>.

=cut

use strict;
use warnings;
use Parse::IRC ();

my @days = qw/ Sun Mon Tue Wed Thu Fri Sat /;
my @months = qw/ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec /;
my %date_markers = (
    d => [ 3, sub { $_[0] < 10 ? "0$_[0]" : $_[0] } ],
    m => [ 4, sub { $_[0] < 10 ? "0" .($_[0] + 1) : $_[0] + 1 } ],
    n => [ 4, sub { @months[$_[0]] } ],
    w => [ 6, sub { @days[$_[0]] } ],
    y => [ 5, sub { $_[0] + 1900 } ],
    H => [ 2, sub { $_[0] < 10 ? "0$_[0]" : $_[0] } ],
    M => [ 1, sub { $_[0] < 10 ? "0$_[0]" : $_[0] } ],
    S => [ 0, sub { $_[0] < 10 ? "0$_[0]" : $_[0] } ],
);

=head1 FUNCTIONS

=head2 pack_irc

  $str = pack_irc $timestamp, $raw_line;

Takes a timestamp and a raw IRC message and packs them together into a string.

=cut

sub pack_irc {
  pack 'Na*', @_;
}

=head2 unpack_irc

    $hash_ref = unpack_irc $str;

=cut

sub unpack_irc {
  my($timestamp, $raw_line) = unpack 'Na*', $_[0];
  my $special = '';
  my $message;

  utf8::decode($raw_line);
  $special = 'me' if $raw_line =~ s/\x{1}ACTION (.*)\x{1}/$1/; # TODO: No idea if this is the right place to put this
  $message = Parse::IRC::parse_irc($raw_line);
  $message->{timestamp} = $timestamp;
  $message->{special} = $special;
  $message;
}

=head2 format_time

  $str = format_time $timestamp, $format;

=cut

sub format_time {
  my @date = localtime shift;
  my $format = shift;

  $format =~ s/%(\w)/
    my $f = $date_markers{$1};
    $f ? $f->[1]->( $date[$f->[0]] ) : $1;
  /ge;

  $format;
}

=head1 METHODS

=head2 import

See L</SYNOPSIS>.

=cut

sub import {
  my($class, @export) = @_;
  my $caller = caller;

  no strict 'refs';
  for my $name (@export) {
      *{ "$caller\::$name" } = \&{ "$class\::$name" };
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;