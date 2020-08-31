package Convos::Date;
use Mojo::Base 'Time::Piece';

use Exporter 'import';
use Scalar::Util 'blessed';

use overload (
  '""'       => sub { shift->datetime },
  'cmp'      => \&Time::Piece::str_compare,
  '+'        => \&Time::Piece::add,
  '-'        => \&Time::Piece::subtract,
  '<=>'      => \&Time::Piece::compare,
  'fallback' => undef,
);

our @EXPORT_OK = qw(dt);

sub dt { __PACKAGE__->parse(@_) }

sub parse {
  my $class = shift;

  # Now
  return scalar $class->gmtime(time) unless @_;

  # Already a Convos::Date object
  return $_[0]->gmtime($_[0]->epoch) if blessed $_[0] and $_[0]->isa('Time::Piece');

  # Epoch
  local $_ = shift;
  return scalar $class->gmtime($_) if /^\d+$|^\d+\.\d+$/;

  # RFC 3339
  $_ =~ s!Z$!!;
  $_ =~ s!\.\d*$!!;
  scalar $class->strptime($_, '%Y-%m-%dT%H:%M:%S');
}

sub TO_JSON { shift->datetime }

1;

=encoding utf8

=head1 NAME

Convos::Date - Convenient subclass of Time::Piece

=head1 SYNOPSIS

  use Convos::Date "dt";
  my $dt = dt;
  my $dt = dt "784111777";
  my $dt = dt "784111777.001";
  my $dt = dt "1994-11-06T08:49:37";
  my $dt = dt "1994-11-06T08:49:37Z";
  my $dt = dt "1994-11-06T08:49:37.001Z";

=head1 DESCRIPTION

L<Convos::Date> exports a single function L</dt> that works with C<gmtime>
dates, instead of C<localtime>. It will also stringify the date using
L<Time::Piece/datetime>, instead of L<Time::Piece/cdate>.

=head1 EXPORTED FUNCTIONS

=head2 dt

  $dt = dt;
  $dt = dt $parse_param;

Calls L</parse> on the input value, and returns a new C<Convos::Date> object.

=head1 METHODS

=head2 parse

  $dt = Convos::Date->parse;
  $dt = Convos::Date->parse(Convos::Date->new);
  $dt = Convos::Date->parse(Time::Piece->new);
  $dt = Convos::Date->parse(1598913750);
  $dt = Convos::Date->parse("2020-08-31T22:26:10");

Used to create a new L<Convos::Date> object from the input given. Called
without any arguments is the same as calling with C<time()>. Passing in a
L<Convos::Date> object willl return a new instance, with the same time.
This method can also parse epoch and RFC-3339 strings.

=head1 SEE ALSO

L<Time::Piece>, L<Convos>.

=cut
