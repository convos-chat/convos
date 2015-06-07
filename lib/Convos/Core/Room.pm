package Convos::Core::Room;

=head1 NAME

Convos::Core::Room - A convos chat room

=head1 DESCRIPTION

L<Convos::Core::Room> is a class describing a L<Convos> chat room.

=head1 SYNOPSIS

  use Convos::Core::Room;
  my $room = Convos::Core::Room->new;

=cut

use Mojo::Base 'Mojo::EventEmitter';

=head1 ATTRIBUTES

=head2 active

  $bool = $self->active;

True if this is a room which the L<user|Convos::Core::User> want to be part of.

=head2 connection

Holds a L<Convos::Core::Connection> object.

=head2 frozen

  $str = $self->frozen;

Descrition of why you are not part of this room anymore.

=head2 id

  $str = $self->id;

Unique identifier for this room.

=head2 name

  $str = $self->name;

The name of this room.

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

has active => 0;
sub connection { shift->{connection} or die 'connection required in constructor' }
has frozen => '';
sub id { shift->{id} or die 'id required in constructor' }
has name => sub { shift->id };
has password => '';
has topic    => '';
has users    => sub { +{} };

=head1 METHODS

=head2 log

  $self = $self->log($level => $format, @args);

This method will emit a "log" event:

  $self->emit(log => $level => $message);

=cut

sub log {
  my ($self, $level, $format, @args) = @_;
  my $message = @args ? sprintf $format, map { $_ // '' } @args : $format;

  $self->emit(log => $level => $message);
}

=head2 n_users

  $int = $self->n_users;

Returns the number of L</users>.

=cut

sub n_users { int keys %{$_[0]->users} || $_[0]->{n_users} || 0 }

=head2 path

  $str = $self->path;

Returns a path to this object.
Example: "/superman@example.com/IRC/irc.perl.org/#convos".

=cut

sub path { join '/', $_[0]->connection->path, $_[0]->id }

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
