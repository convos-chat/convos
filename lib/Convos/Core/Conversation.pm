package Convos::Core::Conversation;

=head1 NAME

Convos::Core::Conversation - A convos conversation base class

=head1 DESCRIPTION

L<Convos::Core::Conversation> is a base class for
L<Convos::Core::Conversation::Direct> and
L<Convos::Core::Conversation::Room>.

=cut

use Mojo::Base -base;

=head1 ATTRIBUTES

=head2 connection

Holds a L<Convos::Core::Connection> object.

=head2 active

  $bool = $self->active;

This is true if the user is currently active in the conversation.

=head2 id

  $str = $self->id;

Unique identifier for this conversation.

=head2 name

  $str = $self->name;

The name of this conversation.

=cut

has active => 0;
sub connection { shift->{connection} or die 'connection required in constructor' }
sub id         { shift->{id}         or die 'id required in constructor' }
has name => sub { shift->id };

=head1 METHODS

=head2 messages

  $self = $self->messages(\%query, sub { my ($self, $err, $messages) = @_; });

Used to get messages which is logged to backend, using L</log>.

See also L<Convos::Core::Backend/messages>.

=cut

sub messages {
  my ($self, $query, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->connection->user->core->backend->messages($self, $query, sub { $self->$cb(@_[1, 2]) });
  $self;
}

=head2 user

  $user = $self->user;
  $user = $self->connection->user;

Shortcut.

=cut

sub user { shift->connection->user }

sub TO_JSON {
  my $self = shift;
  my %json = map { ($_, $self->$_) } qw( active id name );
  $json{connection_id} = $self->connection->id;
  return \%json;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
