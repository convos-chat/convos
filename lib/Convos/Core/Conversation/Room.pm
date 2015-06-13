package Convos::Core::Conversation::Room;

=head1 NAME

Convos::Core::Conversation::Room - A convos chat room

=head1 DESCRIPTION

L<Convos::Core::Conversation::Room> is a class describing a L<Convos> chat room.

=head1 SYNOPSIS

  use Convos::Core::Conversation::Room;
  my $room = Convos::Core::Conversation::Room->new;

=cut

use Mojo::Base 'Convos::Core::Conversation';

=head1 ATTRIBUTES

L<Convos::Core::Conversation::Direct> inherits all attributes from
L<Convos::Core::Conversation> and implements the following new ones.

=head2 frozen

  $str = $self->frozen;

Descrition of why you are not part of this room anymore.

=head2 password

  $str = $self->password;

Holds a password required to join the room.

=head2 topic

  $str = $self->topic;

Holds the topic (subject) for this room.

=head2 users

  $hash_ref = $self->users;

Holds a hash-ref of users. Example:

  {
    $id => {nick => $str},
    ...
  }

C<$id> is ofter lower case version of nick.

=cut

has frozen   => '';
has password => '';
has topic    => '';
has users    => sub { +{} };

=head1 METHODS

L<Convos::Core::Conversation::Direct> inherits all methods from
L<Convos::Core::Conversation> and implements the following new ones.

=head2 n_users

  $int = $self->n_users;

Returns the number of L</users>.

=cut

sub n_users { int keys %{$_[0]->users} || $_[0]->{n_users} || 0 }

sub TO_JSON {
  my $self = shift;
  return {map { ($_, $self->$_) } qw( frozen id name path topic users )};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
