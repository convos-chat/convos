package Convos::Core::Backend;
use Mojo::Base 'Mojo::EventEmitter';

use Mojo::Collection;
use Mojo::JSON qw(false true);
use Mojo::Promise;
use Scalar::Util qw(blessed);

sub connections_p {
  return Mojo::Promise->resolve([]);
}

sub delete_messages_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->resolve($obj);
}

sub delete_object_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->resolve($obj);
}

sub emit_p {
  my ($self, $name) = (shift, shift);
  my $s = $self->{events}{$name} || [];
  return Mojo::Promise->reject("Nothing is subscribing to $name") unless @$s;

  for my $cb (reverse @$s) {
    my $p = $self->$cb(@_);
    return $p if $p and blessed $p and $p->isa('Mojo::Promise');
  }

  return Mojo::Promise->reject("No promise was returned for $name") unless @$s;
}

sub files_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->resolve(Mojo::Collection->new);
}

sub load_object_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->resolve($obj);
}

sub messages_p {
  my ($self, $obj, $query) = @_;
  return Mojo::Promise->resolve({end => true, messages => []});
}

sub new { shift->SUPER::new(@_)->tap('_setup') }

sub notifications_p {
  my ($self, $user, $query) = @_;
  return Mojo::Promise->resolve({end => true, messages => []});
}

sub save_object_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->resolve($obj);
}

sub users_p {
  return Mojo::Promise->resolve([]);
}

sub _setup {
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      my $cid = $connection->id;
      my $uid = $connection->user->id;

      Scalar::Util::weaken($self);
      $connection->on(
        message => sub {
          my ($connection, $target, $msg) = @_;

          if ($msg->{highlight} and $target->id and !$target->is_private) {
            $target->inc_notifications;
          }

          $self->emit("user:$uid",
            message =>
              {connection_id => $cid, conversation_id => $target->id, name => $target->name, %$msg}
          );
        }
      );
      $connection->on(
        state => sub {
          my ($connection, $type, $args) = @_;
          $self->emit("user:$uid", state => {connection_id => $cid, %$args, type => $type});
        }
      );
    }
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Backend - Convos storage backend

=head1 DESCRIPTION

L<Convos::Core::Backend> is a base class for storage backends. See
L<Convos::Core::Backend::File> for code that actually perist data.

=head1 ATTRIBUTES

L<Convos::Core::Backend> inherits all attributes from L<Mojo::EventEmitter> and
implements the following new ones.

=head1 METHODS

L<Convos::Core::Backend> inherits all methods from L<Mojo::EventEmitter> and
implements the following new ones.

=head2 connections_p

  $p = $backend->connections($user)->then(sub { my $connections = shift });

Used to find a list of connection names for a given L<$user|Convos::Core::User>.

=head2 delete_messages_p

  $p = $backend->delete_object_p($obj)->then(sub { my $obj = shift });

This method will delete all messages for a given conversation.

=head2 delete_object_p

  $p = $backend->delete_object_p($obj)->then(sub { my $obj = shift });

This method is called to remove a given object from persistent storage.

=head2 emit_p

  $p = $backend->emit_p($name => @args);

Will call each event handler registered in reverse, and return the first
promise returned by a callback. A rejected promise will be returned if no event
is registered or no callbacks returns a promise.

  $backend->on(cool_beans => sub { return Mojo::Promise->resolve if rand > 0.5 });
  $backend->emit_p('cool_beans')->then(sub { ... });

=head2 files_p

  $p = $backend->files_p($user, {after => '...', limit => 60})->then(sub { my $c = shift });

Gets a list of uploaded files for a L<Convos::Core::User>. C<after> optional,
but can be set to a given file C<id> to provide pagination. C<$c> is a
L<Mojo::Collection> containing file information.

=head2 load_object_p

  $p = $backend->load_object_p($obj)->then(sub { my $obj = shift });

This method will load C<$data> for C<$obj>.

=head2 messages_p

  $p = $backend->messages_p(\%query)->then(sub { my $res = shift; });

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

C<$res> will contain:

  {
    end      => true,
    messages => [...],
  }

=head2 new

Will also call C<_setup()> after the object is created.

=head2 notifications_p

  $p = $backend->notifications_p($user, \%query)->then(sub { my $res = shift; });

This method will return notifications, in the same structure as L</messages>.

=head2 save_object_p

  $backend->save_object_p($obj)->then(sub { my $obj = shift });

This method is called to save a given object to persistent storage.

=head2 users_p

  $backend = $backend->users_p->then(sub { my $users = shift });

Used to find a list of user emails.

=head1 SEE ALSO

L<Convos::Core>

=cut
