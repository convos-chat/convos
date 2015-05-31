package Convos::Model::Connection;

=head1 NAME

Convos::Model::Connection - A Convos connection base class

=head1 DESCRIPTION

L<Convos::Model::Connection> is a base class for L<Convos> connections.

See also L<Convos::Model::Connection::IRC>.

=head1 SYNOPSIS

  use Convos::Model::Connection::YourConnection;
  use Mojo::Base "Convos::Model::Connection";
  # ...
  1;

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Role::Tiny::With;

with qw( Convos::Model::Role::ClassFor Convos::Model::Role::Log );

=head1 EVENTS

=head2 log

  $self->on(log => sub { my ($self, $level, $message) = @_; });

Emitted when a connection want to log a message. C<$level> has the same values
as the log levels defined in L<Mojo::Log>.

These messages could be stored to a persistent storage.

=head2 room

  $self->on(room => sub { my ($self, $room, $changed) = @_; });

Emitted when a L<$room|Convos::Model::Room> change properties. C<$changed> is
a hash-ref with the changed attributes.

=head1 ATTRIBUTES

L<Convos::Model::Connection> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 name

  $str = $self->name;
  $self = $self->name("localhost");

Holds the name of the connection.
Need to be unique per L<user|Convos::Model::User>.

=head2 rooms

  $array_ref = $self->rooms;
  $self = $self->rooms(["#convos", "#channel with-key"]);

Holds a list of rooms / channel names.

=head2 url

Holds a L<Mojo::URL> object which describes where to connect to. This
attribute is read-only.

=head2 user

Holds a L<Convos::Model::User> object that owns this connection.

=cut

has name  => sub { die 'name is required' };
has rooms => sub { [] };

sub url {
  return $_[0]->{url} if ref $_[0]->{url};
  return $_[0]->{url} = Mojo::URL->new($_[0]->{url} || '');
}

has user => sub { die 'user is required' };

=head1 METHODS

L<Convos::Model::Connection> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connect

  $self = $self->connect(sub { my ($self, $err) = @_ });

Used to connect to L</url>. Meant to be overloaded in a subclass.

=cut

sub connect { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "connect" not implemented.'); }

=head2 join_room

  $self = $self->join_room("#some_channel", sub { my ($self, $err) = @_; });

Used to join a room. See also L</room> event.

=cut

sub join_room { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "join_room" not implemented.'); }

=head2 room

  $room = $self->room($id);            # get
  $room = $self->room($id => \%attrs); # create/set

Will return a L<Convos::Model::Room> object, identified by C<$id>.

=cut

sub room {
  my ($self, $id, $attr) = @_;

  if ($attr) {
    my $room = $self->{room}{$id} ||= $self->_class_for('Convos::Model::Room')->new(id => $id);
    $room->{$_} = $attr->{$_} for keys %$attr;
    $room->{home} ||= $self->{home};    # ugly hack
    $self->emit(room => $room, $attr);
    return $room;
  }
  else {
    return $self->{room}{$id} || $self->_class_for('Convos::Model::Room')->new(id => $id);
  }
}

=head2 room_list

  $self = $self->room_list(sub { my ($self, $err, $list) = @_; });

Used to retrieve a list of L<Convos::Model::Room> objects for the given
connection.

=cut

sub room_list { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "room_list" not implemented.', []); }

=head2 send

  $self = $self->send($target => $message, sub { my ($self, $err) = @_; });

Used to send a C<$message> to C<$target>. C<$message> is a plain string and
C<$target> can be a user or room name.

Meant to be overloaded in a subclass.

=cut

sub send { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "send" not implemented.') }

=head2 state

  $self = $self->state($str);
  $str = $self->state;

Holds the state of this object. Supported states are "disconnected",
"connected" or "connecting" (default). "connecting" means that the object is
in the process of connecting or that it want to connect.

=cut

sub state {
  my ($self, $state) = @_;
  return $self->{state} ||= 'connecting' unless $state;
  $self->{state} = $state if grep { $state eq $_ } qw( connected connecting disconnected );
  $self;
}

=head2 topic

  $self = $self->topic($room, sub { my ($self, $err, $topic) = @_; });
  $self = $self->topic($room => $topic, sub { my ($self, $err) = @_; });

Used to retrieve or set topic for a room.

=cut

sub topic { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "topic" not implemented.') }

sub _build_home { Mojo::Home->new($_[0]->user->home->rel_dir($_[0]->_moniker)) }
sub _compose_classes_with { }    # will get role names from around modifiers

sub _setting_keys {
  $_[0]->{rooms} ||= [];
  $_[0]->{url}   ||= Mojo::URL->new;
  return qw( name rooms state url );
}

sub _userinfo {
  my $self = shift;
  my @userinfo = split /:/, $self->url->userinfo // '';
  $userinfo[0] ||= $self->user->email =~ /([^@]+)/ ? $1 : '';
  $userinfo[1] ||= undef;
  return \@userinfo;
}

sub TO_JSON {
  my $self = shift;
  $self->{state} ||= 'connecting';
  return {map { ($_, $self->{$_}) } $self->_setting_keys};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
