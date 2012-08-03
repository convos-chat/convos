package WebIrc::Client;

=head1 NAME

WebIrc::Client

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 view

=cut

sub view {
  my $self = shift;

  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
}

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
