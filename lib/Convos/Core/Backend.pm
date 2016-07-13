package Convos::Core::Backend;
use Mojo::Base 'Mojolicious::Plugins';

has namespaces => sub { ['Convos::Core::Plugin'] };

sub connections {
  return [] if @_ == 1;
  $_[0]->tap($_[2], '', []);
}

sub delete_object {
  $_[0]->tap($_[2], '');
}

sub messages {
  my ($self, $query, $cb) = @_;
  $self->tap($cb, '', []);
}

sub new { shift->SUPER::new(@_)->tap('_setup') }

sub notifications {
  my ($self, $user, $query, $cb) = @_;
  $self->$cb('', []);
  $self;
}

sub save_object {
  my ($self, $obj, $cb) = @_;
  $obj->$cb('') if $cb;
  $self;
}

sub users {
  return [] if @_ == 1;
  $_[0]->tap($_[1], '', []);
}

sub _setup { }

1;

=encoding utf8

=head1 NAME

Convos::Core::Backend - Convos storage backend

=head1 DESCRIPTION

L<Convos::Core::Backend> is a base class for storage backends. See
L<Convos::Core::Backend::File> for code that actually perist data.

=head1 ATTRIBUTES

L<Convos::Core::Backend> inherits all attributes from L<Mojolicious::Plugins>
and implements the following new ones.

=head2 namespaces

  my $namespaces = $plugins->namespaces;
  $plugins       = $plugins->namespaces(["Convos::Core::Plugin"]);

Namespaces to load plugins from, defaults to C<Convos::Core::Plugin>.

=head1 METHODS

L<Convos::Core::Backend> inherits all methods from L<Mojolicious::Plugins>
and implements the following new ones.

=head2 connections

  $self = $self->connections($user, sub { my ($self, $err, $connections) = @_ });

Used to find a list of connection names for a given L<$user|Convos::Core::User>.

=head2 delete_object

  $self = $self->delete_object($obj, sub { my ($self, $err) = @_ });

This method is called to remove a given object from persistent storage.

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

=head2 new

Will also call C<_setup()> after the object is created.

=head2 notifications

  $self->notifications($user, \%query, sub { my ($self, $err, $notifications) = @_; });

This method will return notifications, in the same structure as L</messages>.

=head2 save_object

  $self->save_object($obj, sub { my ($obj, $err) = @_; });

This method is called to save a given object to persistent storage.

=head2 users

  $self = $self->users(sub { my ($self, $err, $users) = @_ });

Used to find a list of user emails.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
