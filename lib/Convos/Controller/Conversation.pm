package Convos::Controller::Conversation;

=head1 NAME

Convos::Controller::Conversation - Convos chat actions

=head1 DESCRIPTION

L<Convos::Controller::Conversation> is a L<Mojolicious::Controller> with
user related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 conversation_join

See L<Convos::Manual::API/conversationJoin>.

=cut

sub conversation_join {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{protocol}, $args->{connection_name});

  $self->delay(
    sub { $connection->join_conversation($args->{data}{name}, shift->begin) },
    sub {
      my ($delay, $err, $room) = @_;
      return $self->$cb($self->invalid_request($err, '/data/name'), 400) if $err;
      $connection->save($delay->begin);
      $delay->pass($room);
    },
    sub {
      my ($delay, $err, $room) = @_;
      die $err if $err;
      $self->$cb($room->TO_JSON, 200);
    },
  );
}

=head2 conversation_messages

See L<Convos::Manual::API/conversationMessages>.

=cut

sub conversation_messages {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{protocol}, $args->{connection_name}) or return $self->$cb({});
  my $conversation = $connection->conversation($args->{conversation_id});
  my %query;

  # TODO:
  $query{$_} = $args->{$_} for grep { defined $args->{$_} } qw( after before level limit match );

  $self->delay(
    sub { $conversation->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      $self->$cb({messages => $messages}, 200);
    },
  );
}

=head2 conversation_delete

See L<Convos::Manual::API/conversationDelete>.

=cut

sub conversation_delete {
  my ($self, $args, $cb) = @_;

  die 'TODO';

  $self->$cb({message => ''}, 200);
}

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

  $self->$cb({conversations => \@conversations}, 200);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
