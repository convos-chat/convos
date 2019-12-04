package Convos::Core::Dialog;
use Mojo::Base -base;

use Convos::Util;
use Mojo::Date;

my $CHANNEL_RE = qr{[#&]};

has frozen   => '';
has name     => sub { Carp::confess('name required in constructor') };
has password => '';
has topic    => '';

sub connection { shift->{connection} or Carp::confess('connection required in constructor') }
sub id         { my $from = $_[1] || $_[0]; lc($from->{id} // $from->{name}) }

has last_active => sub { Mojo::Date->new->to_datetime };
has last_read   => sub { Mojo::Date->new->to_datetime };

sub is_private { shift->name =~ /^$CHANNEL_RE/ ? 0 : 1 }

sub messages_p {
  my ($self, $query) = @_;
  return $self->connection->user->core->backend->messages_p($self, $query);
}

sub calculate_unread_p {
  my $self = shift;

  return $self->messages_p({after => $self->last_read, limit => 61})->then(sub {
    my $messages = shift;
    return $self->{unread} = int @$messages;
  });
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my %json = map { ($_, $self->$_) } qw(frozen name last_active last_read topic);
  $json{connection_id} = $self->connection->id;
  $json{dialog_id}     = $self->id;
  $json{password}      = $self->password if $persist;
  $json{unread}        = $self->{unread} || 0;
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

=head2 name

  $str = $self->name;

The name of this dialog.

=head2 last_active

  $datetime = $self->last_active;
  $self = $self->last_active($datetime);

Holds an datetime timestring of last time this dialog received a message.

=head2 last_read

  $datetime = $self->last_read;
  $self = $self->last_read($datetime);

Holds an datetime timestring of last time this dialog was active in frontend.

=head2 password

  $str = $self->password;

The password used to join this dialog.

=head2 topic

  $str = $self->topic;

The topic (subject) of the dialog.

=head1 METHODS

=head2 is_private

  $bool = $self->is_private;

Returns true if you are only talking to a single user and no other
participants can join the dialog.

=head2 messages_p

  $p = $self->messages_p(\%query)->then(sub { my $messages = shift; });

Will fetch messages from persistent backend.

See also L<Convos::Core::Backend/messages>.

=head2 calculate_unread_p

  $p = $self->calculate_unread_p;

Used to find the number of unread messages after L</last_read>.

This method is EXPERIMENTAL.

=head1 SEE ALSO

L<Convos::Core>.

=cut
