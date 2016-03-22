package Convos::Core;
use Mojo::Base -base;
use Mojolicious::Plugins;
use Convos::Core::Backend;
use Convos::Core::User;
use Convos::Util 'has_many';

sub backend { shift->{backend} ||= Convos::Core::Backend->new }

sub connect {
  my ($self, $connection) = @_;
  my $host = $connection->url->host;

  $connection->state('connecting');

  if ($host eq 'localhost') {
    $connection->connect(sub { });
  }
  elsif ($self->{connect_queue}{$host}) {
    push @{$self->{connect_queue}{$host}}, $connection;
  }
  else {
    $self->{connect_queue}{$host} = [];
    $connection->connect(sub { });
  }

  return $self;
}

sub start {
  my $self = shift;

  return $self if !@_ and $self->{started}++;

  # Want this method to be blocking to make sure everything is ready
  # before processing web requests.
  for (@{$self->backend->users}) {
    my $user = $self->user($_);
    for (@{$self->backend->connections($user)}) {
      my $connection = $user->connection($_);
      $self->connect($connection) unless $connection->state eq 'disconnected';
    }
  }

  Scalar::Util::weaken($self);
  $self->{connect_tid} = Mojo::IOLoop->timer(
    $ENV{CONVOS_CONNECT_DELAY} || 3,
    sub {
      for my $host (keys %{$self->{connect_queue} || {}}) {
        my $connection = shift @{$self->{connect_queue}{$host}} or next;
        next if $connection->state eq 'disconnected' and $connection->url->host ne $host;
        $connection->connect(
          sub {
            my ($connection, $err) = @_;
            push @{$self->{connect_queue}{$host}}, $connection if $err;
          }
        );
      }
    }
  );

  return $self;
}

has_many users => 'Convos::Core::User' => sub {
  my ($self, $attrs) = @_;
  my $user = Convos::Core::User->new($attrs);
  die "Invalid email $user->{email}. Need to match /.\@./." unless $user->email =~ /.\@./;
  Scalar::Util::weaken($user->{core} = $self);
  return $user;
};

sub DESTROY {
  my $self = shift;
  Mojo::IOLoop->remove($self->{connect_tid}) if $self->{connect_tid};
}

1;

=encoding utf8

=head1 NAME

Convos::Core - Convos Models

=head1 DESCRIPTION

L<Convos::Core> is a class which is used to instantiate other core objects
with proper defaults.

=head1 SYNOPSIS

  use Convos::Core;
  use Convos::Core::Backend::File;
  my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);

=head1 OBJECT GRAPH

=over 2

=item * L<Convos::Core>

=over 2

=item * Has one L<Convos::Core::Backend> objects.

This object takes care of persisting data to disk.

=item * Has many L<Convos::Core::User> objects.

Represents a user of L<Convos>.

=over 2

=item * Has many L<Convos::Core::Connection> objects.

Represents a connection to a remote chat server, such as an
L<IRC|Convos::Core::Connection::Irc> server.

=over 2

=item * Has many L<Convos::Core::Dialog> objects.

This represents a dialog with zero or more users.

=back

=back

=back

=back

All the child objects have pointers back to the parent object.

=head1 ATTRIBUTES

L<Convos::Core> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 backend

  $obj = $self->backend;

Holds a L<Convos::Core::Backend> object.

=head1 METHODS

L<Convos::Core> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connect

  $self->connect($connection);

This method will call L<Convos::Core::Connection/connect> either at once
or add the connection to a queue which will connect after an interval.

The reason for queuing connections is to prevent flooding the server.

Note: Connections to "localhost" will not be delayed.

=head2 get_user

  $user = $self->get_user(\%attrs);
  $user = $self->get_user($email);

Returns a L<Convos::Core::User> object or undef.

=head2 start

  $self = $self->start;

Will start the backend. This means finding all users and start connections
if state is not "disconnected".

=head2 user

  $user = $self->user(\%attrs);

Returns a new L<Convos::Core::User> object or updates an existing object.

=head2 users

  $users = $self->users;

Returns an array-ref of of L<Convos::Core::User> objects.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
