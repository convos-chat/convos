package Convos::Controller::Conversation;

=head1 NAME

Convos::Controller::Conversation - Convos conversations

=head1 DESCRIPTION

L<Convos::Controller::Conversation> is a L<Mojolicious::Controller> with
conversation related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 join

See L<Convos::Manual::API/joinConversation>.

=cut

sub join {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{connection_id}) or return $self->$cb({}, 404);

  $self->delay(
    sub { $connection->join_conversation($args->{body}{name}, shift->begin) },
    sub {
      my ($delay, $err, $room) = @_;
      return $self->$cb($self->invalid_request($err, '/body/name'), 400) if $err;
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

=head2 list

See L<Convos::Manual::API/listConversations>.

=cut

sub list {
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

=head2 messages

See L<Convos::Manual::API/messagesForConversation>.

=cut

sub messages {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{connection_id}) or return $self->$cb({}, 404);
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

=head2 remove

See L<Convos::Manual::API/removeConversation>.

=cut

sub remove {
  my ($self, $args, $cb) = @_;
  die 'TODO';
  $self->$cb({message => ''}, 200);
}

=head2 send

See L<Convos::Manual::API/sendToConversation>.

=cut

sub send {
  my ($self, $args, $cb) = @_;
  die 'TODO';
  $self->$cb({message => ''}, 200);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
