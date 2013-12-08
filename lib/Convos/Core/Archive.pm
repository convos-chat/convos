package Convos::Core::Archive;

=head1 NAME

Convos::Core::Archive - Backend archive

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;

=head1 ATTRIBUTES

=head2 archive

What is this?

=cut

has 'archive';

=head2 ack

What is this?

=cut

has 'ack' => sub {};

=head1 METHODS

=head2 search

  TODO = $self->search(TODO);

=cut

sub search {
  my $self=shift;
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
