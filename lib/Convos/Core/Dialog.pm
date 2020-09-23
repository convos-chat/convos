package Convos::Core::Dialog;
use Mojo::Base -base;

use Convos::Util '$CHANNEL_RE';
use Mojo::Date;

has frozen   => '';
has name     => sub { Carp::confess('name required in constructor') };
has password => '';
has topic    => '';
has unread   => 0;

sub connection { shift->{connection} or Carp::confess('connection required in constructor') }
sub id         { my $from = $_[1] || $_[0]; lc($from->{id} // $from->{name}) }
sub is_private { shift->name =~ /^$CHANNEL_RE/ ? 0 : 1 }

sub inc_unread_p {
  my $self = shift;
  $self->{unread}++;
  return Mojo::Promise->resolve($self);
}

sub messages_p {
  my ($self, $query) = @_;
  return $self->connection->user->core->backend->messages_p($self, $query);
}

# back compat - will be removed in future version
sub _calculate_unread_p {
  my $self = shift;
  return unless my $last_read = delete $self->{last_read};
  return $self->messages_p({after => $last_read, limit => 61})
    ->then(sub { $self->unread(int @{shift->{messages}}) });
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my %json = map { ($_, $self->$_) } qw(frozen name topic unread);
  $json{connection_id} = $self->connection->id;
  $json{dialog_id}     = $self->id;
  $json{last_read}     = $self->{last_read} if $self->{last_read};    # back compat
  $json{password}      = $self->password if $persist;
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

  $str = $dialog->frozen;

Will be set to a description if the dialog is "frozen", which means you are
no longer part of it.

=head2 id

  $str = $dialog->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a dialog.

=head2 name

  $str = $dialog->name;

The name of this dialog.

=head2 password

  $str = $dialog->password;

The password used to join this dialog.

=head2 topic

  $str = $dialog->topic;

The topic (subject) of the dialog.

=head2 unread

  $int = $dialog->unread;

Holds the number of unread messages.

=head1 METHODS

=head2 inc_unread_p

  $p = $dialog->inc_unread_p;

Used to increase the unread count.

=head2 is_private

  $bool = $dialog->is_private;

Returns true if you are only talking to a single user and no other
participants can join the dialog.

=head2 messages_p

  $p = $dialog->messages_p(\%query)->then(sub { my $messages = shift; });

Will fetch messages from persistent backend.

See also L<Convos::Core::Backend/messages>.

=head1 SEE ALSO

L<Convos::Core>.

=cut
