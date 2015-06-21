package Convos::Controller::Chat;

=head1 NAME

Convos::Controller::Chat - Convos chat actions

=head1 DESCRIPTION

L<Convos::Controller::Chat> is a L<Mojolicious::Controller> with
user related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 conversations

See L<Convos::Manual::API/conversations>.

=cut

sub conversations {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @conversations;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $conversation (sort { $a->id cmp $b->id } @{$connection->conversations}) {
      push @conversations, $conversation->TO_JSON if $conversation->active;
    }
  }

  $self->$cb(\@conversations, 200);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
