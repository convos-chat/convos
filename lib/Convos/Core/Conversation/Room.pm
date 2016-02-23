package Convos::Core::Conversation::Room;
use Mojo::Base 'Convos::Core::Conversation';

has frozen   => '';
has password => '';
has topic    => '';
has users    => sub { +{} };

sub n_users { int keys %{$_[0]->users} || $_[0]->{n_users} || 0 }

sub TO_JSON {
  my ($self, $persist) = @_;
  my $json = $self->SUPER::TO_JSON($persist);

  $json->{$_} = $self->$_ for qw( frozen topic);
  $json->{users} = $self->users unless $persist;
  $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Conversation::Room - A convos chat room

=head1 DESCRIPTION

L<Convos::Core::Conversation::Room> is a class describing a L<Convos> chat room.

=head1 SYNOPSIS

  use Convos::Core::Conversation::Room;
  my $room = Convos::Core::Conversation::Room->new;

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

=head1 METHODS

L<Convos::Core::Conversation::Direct> inherits all methods from
L<Convos::Core::Conversation> and implements the following new ones.

=head2 n_users

  $int = $self->n_users;

Returns the number of L</users>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
