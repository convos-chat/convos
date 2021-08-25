package Convos::Core::Backend::SQLite;
use Mojo::Base 'Convos::Core::Backend';

use Mojo::SQLite;
use Convos::Date qw(dt);
use Mojo::JSON qw(false true);

has home   => sub { Carp::confess('home() cannot be built') };
has sqlite => sub {
  my $self = shift;
  $self->home->make_path unless -d $self->home;

  my $sqlite = Mojo::SQLite->new('sqlite:' . $self->home->child('convos.sqlite'));
  $sqlite->migrations->from_file(...)->migrate;
  return $sqlite;
};

sub connections_p {
  my ($self, $user) = @_;

  return $self->_db->select_p('convos_connections')->then(sub {
    return shift->hashes->to_array;
  });
}

sub delete_messages_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->reject('Unknown target.') unless $obj and $obj->connection;
  return $self->_db->delete_p(convos_messages => {conversation_id => $obj->id})->then(sub {$obj});
}

sub delete_object_p {
  my ($self, $obj) = @_;

  if ($obj->isa('Convos::Core::Connection')) {
    $obj->unsubscribe($_) for qw(conversation message state);
  }

  return $self->_db->delete_p($self->_obj_to_table($obj), {id => $obj->id})->then(sub {$obj});
}

sub load_object_p {
  my ($self, $obj) = @_;

  return $self->_db->select_p($self->_obj_to_table($obj), {id => $obj->id})->then(sub {
    return shift->hash;
  });
}

sub messages_p {
  my ($self, $obj, $query) = @_;

  if ($query->{around}) {
    my %query_before = (%$query, around => undef, before => $query->{around});
    my %query_after  = (%$query, around => undef, after  => $query->{around}, include => 1);

    return Mojo::Promise->all(
      $self->messages_p($obj, \%query_before),
      $self->messages_p($obj, \%query_after),
    )->then(sub {
      my ($before, $after) = map { $_->[0] } @_;
      return {%$before, %$after, messages => [map { @{$_->{messages}} } ($before, $after)]};
    });
  }

  my %extra = (limit => $query->{limit} || 60);
  $extra{order_by} = {-desc => 'ts'};

  my %where = (id => $obj->id);
  $where{from} = $query->{from} if $query->{from};

  my $lt = $query->{include} ? '<=' : '<';
  my $gt = $query->{include} ? '>=' : '>';
  push @{$where{ts}}, {$gt => dt $query->{after}}  if $query->{after};
  push @{$where{ts}}, {$lt => dt $query->{before}} if $query->{before};

  return $self->_db->select_p(convos_messages => \%where, \%extra)->then(sub {
    return shift->hashes->to_array;
  });
}

sub notifications_p {
  my ($self, $user, $query) = @_;

  my %extra = (limit => $query->{limit} || 60);
  $extra{order_by} = {-desc => 'ts'};

  return $self->_db->select_p(convos_notifications => {}, \%extra)->then(sub {
    return shift->hashes->to_array;
  });
}

sub save_object_p {
  my ($self, $obj) = @_;

  return $self->_db->insert_p($self->_obj_to_table($obj), $obj->TO_JSON('private'))
    ->then(sub {$obj});
}

sub users_p {
  my $self = shift;

  return $self->_db->select_p('convos_users')->then(sub {
    return shift->hashes->sort(sub {
      $a->{registered} cmp $b->{registered} || $a->{email} cmp $b->{email};
    })->to_array;
  });
}

sub _add_message_p {
  my ($self, $target, $msg) = @_;

  return $self->_db->insert_p(
    convos_notifications => {
      connection_id   => $target->connection->id,
      conversation_id => $target->id,
      from            => $msg->{from},
      highlight       => $msg->{highlight} ? 1 : 0,
      message         => $msg->{message},
      ts              => dt($msg->{ts})->to_datetime,
      type            => $msg->{type} || 'normal',
    }
  );
}

sub _add_notification_p {
  my ($self, $target, $msg) = @_;

  return $self->_db->insert_p(
    convos_notifications => {
      connection_id   => $target->connection->id,
      conversation_id => $target->id,
      from            => $msg->{from},
      message         => $msg->{message},
      ts              => dt($msg->{ts})->to_datetime,
      type            => $msg->{type} || 'normal',
    }
  );
}

sub _db { shift->sqlite->db }

sub _obj_to_table {
  my ($self, $obj) = @_;
  return 'convos_connections'   if $obj->isa('Convos::Core::Connection');
  return 'convos_conversations' if $obj->isa('Convos::Core::Conversation');
  return 'convos_settings'      if $obj->isa('Convos::Core::Settings');
  return 'convos_users'         if $obj->isa('Convos::Core::User');
  return 'convos_unknown_object';
}

sub _setup {
  my $self = shift;

  Scalar::Util::weaken($self);
  my $catch = sub { $self->emit(error => shift) };

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
            $self->_add_notification_p($target, $msg)->catch($catch);
            $connection->user->save_p->catch($catch);
          }

          $self->_add_message_p($target, $msg)->catch($catch);
        }
      );
    }
  );

  return $self->SUPER::_setup;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Backend::SQLite - Backend for storing objects to SQLite

=head1 DESCRIPTION

L<Convos::Core::Backend::SQLite> contains methods which is useful for objects
that want to be persisted to an SQLite database.

=head2 Where is data stored

C<CONVOS_HOME> can be set to specify the root location for where to save store
the SQLite database. The default directory on *nix systems is something like
this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=head1 ATTRIBUTES

L<Convos::Core::Backend::File> inherits all attributes from
L<Convos::Core::Backend> and implements the following new ones.

=head2 home

See L<Convos::Core/home>.

=head2 sqlite

  $sqlite = $backend->sqlite;

Returns a L<Mojo::SQLite> object.

=head1 METHODS

L<Convos::Core::Backend::File> inherits all methods from
L<Convos::Core::Backend> and implements the following new ones.

=head2 connections_p

See L<Convos::Core::Backend/connections_p>.

=head2 delete_messages_p

See L<Convos::Core::Backend/delete_messages_p>.

=head2 delete_object_p

See L<Convos::Core::Backend/delete_object_p>.

=head2 load_object_p

See L<Convos::Core::Backend/load_object_p>.

=head2 messages_p

See L<Convos::Core::Backend/messages_p>.

=head2 notifications_p

See L<Convos::Core::Backend/notifications_p>.

=head2 save_object_p

See L<Convos::Core::Backend/save_object_p>.

=head2 users_p

See L<Convos::Core::Backend/users_p>.

=head1 SEE ALSO

L<Convos::Core>.

=cut
