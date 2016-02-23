package Convos::Controller::Notifications;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my ($self, $arg, $cb) = @_;
  die 'TODO';
  $self->$cb({notifications => []}, 200);
}

sub seen {
  my ($self, $arg, $cb) = @_;
  die 'TODO';
  $self->$cb({}, 200);
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Notifications - Convos notifications

=head1 DESCRIPTION

L<Convos::Controller::Notifications> is a L<Mojolicious::Controller> with
notifications related actions.

=head1 METHODS

=head2 list

See L<Convos::Manual::API/listNotifications>.

=head2 seen

See L<Convos::Manual::API/seenNotifications>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
