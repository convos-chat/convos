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
    utf8::decode($raw_line);
    my $message = Parse::IRC::parse_irc($raw_line);
    $message->{timestamp} = $timestamp;
    $message;
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