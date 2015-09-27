package Convos::Core::Backend;

=head1 NAME

Convos::Core::Backend - Convos storage backend

=head1 DESCRIPTION

L<Convos::Core::Backend> is a base class for storage backends. See
L<Convos::Core::Backend::File> for code that actually perist data.

=cut

use Mojo::Base 'Mojolicious::Plugins';

=head1 ATTRIBUTES

L<Convos::Core::Backend> inherits all attributes from L<Mojolicious::Plugins>
and implements the following new ones.

=head2 namespaces

  my $namespaces = $plugins->namespaces;
  $plugins       = $plugins->namespaces(["Convos::Core::Plugin"]);

Namespaces to load plugins from, defaults to C<Convos::Core::Plugin>.

=cut

has namespaces => sub { ['Convos::Core::Plugin'] };

=head1 METHODS

L<Convos::Core::Backend> inherits all methods from L<Mojolicious::Plugins>
and implements the following new ones.

=head2 find_connections

  $self = $self->find_connections($user, sub { my ($self, $err, $connections) = @_ });

Used to find a list of connection names for a given L<$user|Convos::Core::User>.

=cut

sub find_connections {
  $_[0]->tap($_[2], '', []);
}

=head2 find_users

  $self = $self->find_users(sub { my ($self, $err, $users) = @_ });

Used to find a list of user emails.

=cut

sub find_users {
  $_[0]->tap($_[1], '', []);
}

=head2 messages

  $self->messages(\%query, sub { my ($self, $err, $messages) = @_; });

Used to search for messages stored in backend. The callback will be called
with the messages found.

Possible C<%query>:

  {
    after  => $datetime, # find messages after a given ISO 8601 timestamp
    before => $datetime, # find messages before a given ISO 8601 timestamp
    level  => $str,      # debug, info (default), warn, error
    limit  => $int,      # max number of messages to retrieve
    match  => $regexp,   # filter messages by a regexp
  }

=cut

sub messages {
  my ($self, $query, $cb) = @_;
  $self->tap($cb, '', []);
}

=head2 new

Will also call C<_setup()> after the object is created.

=cut

sub new {
  my $self = shift->SUPER::new(@_);
  $self->_setup;
  $self;
}

=head2 load_object

  $self->load_object($obj, sub { my ($obj, $err) = @_; });

=cut

sub load_object {
  my ($self, $obj, $cb) = @_;
  $obj->$cb('') if $cb;
  $self;
}

=head2 save_object

  $self->save_object($obj, sub { my ($obj, $err) = @_; });

=cut

sub save_object {
  my ($self, $obj, $cb) = @_;
  $obj->$cb('') if $cb;
  $self;
}

sub _setup { }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
