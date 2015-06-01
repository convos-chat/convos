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

=head2 topic

  $str = $self->topic;

Holds the topic (subject) for this room.

=head2 users

  $hash_ref = $self->users;

=cut

sub connection { shift->{connection} or die 'connection required in constructor' }
has frozen => '';
sub id { shift->{id} or die 'id required in constructor' }
has name => sub { shift->id };
has topic => '';
has users => sub { +{} };

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

sub _path { join '/', $_[0]->connection->_path, $_[0]->id }

sub TO_JSON {
  my $self = shift;
  return {frozen => $self->frozen, id => $self->id, name => $self->name, topic => $self->topic, users => $self->users};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
