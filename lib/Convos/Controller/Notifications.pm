package Convos::Controller::Notifications;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my %query;

  # TODO:
  $query{$_} = $args->{$_} for grep { defined $args->{$_} } qw(limit match);

  $self->delay(
    sub { $user->notifications(\%query, shift->begin) },
    sub {
      my ($delay, $err, $notifications) = @_;
      die $err if $err;
      $self->$cb({notifications => $notifications}, 200);
    },
  );
}

sub seen {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  $user->unseen(0);
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
