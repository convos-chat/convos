package Convos::Core::Conversation;
use Mojo::Base -base;

has active => 0;
sub connection { shift->{connection} or die 'connection required in constructor' }
sub id         { shift->{id}         or die 'id required in constructor' }
has name => sub { shift->id };

sub messages {
  my ($self, $query, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->connection->user->core->backend->messages($self, $query, sub { $self->$cb(@_[1, 2]) });
  $self;
}

sub user { shift->connection->user }

sub TO_JSON {
  my $self = shift;
  my %json = map { ($_, $self->$_) } qw( active id name );
  $json{connection_id} = $self->connection->id;
  return \%json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Conversation - A convos conversation base class

=head1 DESCRIPTION

L<Convos::Core::Conversation> is a base class for
L<Convos::Core::Conversation::Direct> and
L<Convos::Core::Conversation::Room>.

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

=head1 METHODS

=head2 messages

  $self = $self->messages(\%query, sub { my ($self, $err, $messages) = @_; });

Will fetch messages from persistent backend.

See also L<Convos::Core::Backend/messages>.

=head2 user

  $user = $self->user;
  $user = $self->connection->user;

Shortcut.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
