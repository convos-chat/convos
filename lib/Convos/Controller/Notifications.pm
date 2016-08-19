package Convos::Controller::Notifications;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my %query;

  # TODO:
  $query{$_} = $self->param($_) for grep { defined $self->param($_) } qw(limit match);

  $self->delay(
    sub { $user->notifications(\%query, shift->begin) },
    sub {
      my ($delay, $err, $notifications) = @_;
      die $err if $err;
      $self->render(openapi => {notifications => $notifications});
    },
  );
}

sub read {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  $self->delay(
    sub { $user->unread(0)->save(shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(openapi => {});
    }
  );
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

=head2 read

See L<Convos::Manual::API/readNotifications>.

=head1 SEE ALSO

L<Convos>.

=cut
