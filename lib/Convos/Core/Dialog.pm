package Convos::Core::Dialog;
use Mojo::Base -base;

my $CHANNEL_RE = qr{[#&]};

has frozen => '';
has is_private => sub { shift->name =~ /^$CHANNEL_RE/ ? 0 : 1 };
has name => sub { Carp::confess('name required in constructor') };
has password => '';
has topic    => '';

sub connection { shift->{connection} or Carp::confess('connection required in constructor') }

sub id { lc +($_[1] || $_[0])->{name} }

sub messages {
  my ($self, $query, $cb) = @_;
  Scalar::Util::weaken($self);
  $self->connection->user->core->backend->messages($self, $query, sub { $self->$cb(@_[1, 2]) });
  $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my %json = map { ($_, $self->$_) } qw(frozen id is_private name topic);
  $json{connection_id} = $self->connection->id;
  $json{password} = $self->password if $persist;
  return \%json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Dialog - A convos dialog base class

=head1 DESCRIPTION

L<Convos::Core::Dialog> represents a dialog (conversation) with one or
more participants.

=head1 ATTRIBUTES

=head2 connection

Holds a L<Convos::Core::Connection> object.

=head2 frozen

  $str = $self->frozen;

Will be set to a description if the dialog is "frozen", which means you are
no longer part of it.

=head2 id

  $str = $self->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a dialog.

=head2 is_private

  $bool = $self->is_private;

Returns true if you are only talking to a single user and no other
participants can join the dialog.

=head2 name

  $str = $self->name;

The name of this dialog.

=head2 password

  $str = $self->password;

The password used to join this dialog.

=head2 topic

  $str = $self->topic;

The topic (subject) of the dialog.

=head1 METHODS

=head2 messages

  $self = $self->messages(\%query, sub { my ($self, $err, $messages) = @_; });

Will fetch messages from persistent backend.

See also L<Convos::Core::Backend/messages>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
