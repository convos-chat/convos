package Convos::Controller::Archive;

=head1 NAME

Convos::Controller::Archive - Mojolicious Controller for IRC logs

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 list

Retrieves previous conversations.

=cut

sub list {
  my $self = shift;
}

=head2 view

View a previous conversation.

=cut

sub view {
  my $self = shift;
}

=head2 search

Search in previous conversations. See also L<Convos::Core::Archive/search>.

=cut

sub search {
  my $self = shift;
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
