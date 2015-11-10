package Convos::Core;

=head1 NAME

Convos::Core - Convos Models

=head1 DESCRIPTION

L<Convos::Core> is a class which is used to instantiate other core objects
with proper defaults.

=head1 SYNOPSIS

  use Convos::Core;
  my $core = Convos::Core->new;
  my $user = $core->user($email);

=head1 OBJECT GRAPH

=over 4

=item * L<Convos::Core>

=over 4

=item * Has one L<Convos::Core::Backend> objects.

This object takes care of persisting data to disk.

=item * Has many L<Convos::Core::User> objects.

Represents a user of L<Convos>.

=over 4

=item * Has many L<Convos::Core::Connection> objects.

Represents a connection to a remote chat server, such as an
L<IRC|Convos::Core::Connection::Irc> server.

=over 4

=item * Has many L<Convos::Core::Conversation::Direct> objects.

This represents a conversation with a single user.

=item * Has many L<Convos::Core::Conversation::Room> objects.

This represents a conversation with other users.

=back

=back

=back

=back

All the child objects have pointers back to the parent object.

=cut

use Mojo::Base -base;
use Mojolicious::Plugins;
use Convos::Core::Backend;
use Convos::Core::User;
use List::Util 'pairmap';
use constant CONNECT_TIMER => $ENV{CONVOS_CONNECT_TIMER} || 3;
use constant DEBUG         => $ENV{CONVOS_DEBUG}         || 0;

=head1 ATTRIBUTES

L<Convos::Core> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 backend

  $obj = $self->backend;

Holds a L<Convos::Core::Backend> object.

=cut

sub backend { shift->{backend} ||= Convos::Core::Backend->new }

=head1 METHODS

L<Convos::Core> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 start

  $self = $self->start;

Will start the backend. This means finding all users and start connections
if state is not "disconnected".

=cut

sub start {
  my $self = shift;

  return $self if !@_ and $self->{started}++;

  # Want this method to be blocking to make sure everything is ready
  # before processing web requests.
  for my $user (@{$self->backend->users}) {
    $self->user($user);
    for my $c (@{$self->backend->connections($user)}) {
      $user->connection($c);
      $c->connect(sub { }) if $c->state ne 'disconnected';
    }
  }

  return $self;
}

=head2 user

  $user = $self->user($email); # get
  $user = $self->user(\%attr); # create

Returns a L<Convos::Core::User> object. Every new object created will emit
a "user" event:

  $self->backend->emit(user => $user);

=cut

sub user {
  my ($self, $obj) = @_;

  # Get
  return $self->{users}{$obj} unless ref $obj;

  # Add
  Scalar::Util::weaken($obj->{core} = $self);
  $obj = Convos::Core::User->new($obj) if ref $obj eq 'HASH';

  die "Invalid email $obj->{email}. Need to match /.\@./." unless $obj->email =~ /.\@./;
  die "User already exists." if $self->{users}{$obj->email};

  $self->{users}{$obj->email} = $obj;
  warn "[$obj->{email}] Emit user" if DEBUG;
  $self->backend->emit(user => $obj);
  return $obj;
}

=head2 users

  $users = $self->users;

Returns an array-ref of of L<Convos::Core::User> objects.

=cut

sub users { [values %{$_[0]->{users} || {}}] }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
