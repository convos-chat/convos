package Convos::Controller::Notifications;

=head1 NAME

Convos::Controller::Notifications - Convos notifications

=head1 DESCRIPTION

L<Convos::Controller::Notifications> is a L<Mojolicious::Controller> with
notifications related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 list

See L<Convos::Manual::API/listNotifications>.

=cut

sub list {
  my ($self, $arg, $cb) = @_;
  die 'TODO';
  $self->$cb({notifications => []}, 200);
}

=head2 seen

See L<Convos::Manual::API/seenNotifications>.

=cut

sub seen {
  my ($self, $arg, $cb) = @_;
  die 'TODO';
  $self->$cb({}, 200);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
