package Convos::Controller::Notifications;
use Mojo::Base 'Mojolicious::Controller';

sub messages {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my %query = map { defined $self->param($_) ? ($_, $self->param($_)) : () } qw(limit match);

  return $user->notifications_p(\%query)->then(sub {
    my $res = shift;
    $self->render(openapi => {end => $res->{end}, messages => $res->{messages}});
  });
}

sub read {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  return $user->unread(0)->save_p->then(sub { $self->render(openapi => {}) });
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Notifications - Convos notifications

=head1 DESCRIPTION

L<Convos::Controller::Notifications> is a L<Mojolicious::Controller> with
notifications related actions.

=head1 METHODS

=head2 messages

See L<Convos::Manual::API/notificationMessages>.

=head2 read

See L<Convos::Manual::API/readNotifications>.

=head1 SEE ALSO

L<Convos>.

=cut
