package Convos::Archive;

=head1 NAME

Convos::Archive - Convos message archiver

=head1 DESCRIPTION

L<Convos::Archive> is used to archive messages, making them accessible
from a storage on disk instead of in memory.

=cut

use Mojo::Base -base;

=head1 METHODS

=head2 save

  $self = $self->save($connection, $data);

Write a log C<$message> from a C<$connection> message.

=head2 search

  $self = $self->search(sub { my ($self, @messages) = @_; });

Used to retrieve a list of messages with the same format as L</save> would
take as input.

=cut

sub save   { die "save() is not implemented for $_[0]" }
sub search { die "search() is not implemented for $_[0]" }

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
