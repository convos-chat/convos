package Convos::Archive::File;

=head1 NAME

Convos::Archive::File - Archive to file

=head1 DESCRIPTION

L<Convos::Archive::File> is a subclass of L<Convos::Archive> which use plain
files on disk.

=cut

use Mojo::Base 'Convos::Archive';
use File::Path 'make_path';
use File::Spec::Functions qw( catdir catfile );
use Time::Piece ();

=head1 ATTRIBUTES

=head2 log_dir

Path to write logs in.

=cut

has log_dir => sub { die "log_dir() need to be defined in constructor"; };

=head1 METHODS

=head2 save

See L<Convos::Archive/save>.

=cut

use Time::Piece qw/gmtime/;

sub save {
  my ($self, $conn, $message) = @_;
  my $ts = gmtime($message->{timestamp});

  my @base = ($self->log_dir, $conn->login, $conn->name);
  push @base, $message->{target} if $message->{target};
  push @base, $ts->strftime('%y'), $ts->strftime('%m');
  my $path = catdir(@base);
  make_path $path unless $self->{paths}{$path}++;

  $path = catfile $path, $ts->strftime('%d.log');
  open my $FH, '>>', $path or die "Cannot write to $path: $!";
  printf {$FH} "%s :%s!%s@%s %s\n", $ts->hms, map { $_ // '' } @{$message}{qw(nick user host message)};
  close $FH or die "Cannot close $path: $!";
  return $self;
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
