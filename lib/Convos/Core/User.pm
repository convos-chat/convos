package Convos::Core::User;
use Mojo::Base 'Mojo::EventEmitter';

use Convos::Core::Connection;
use Convos::Util qw(DEBUG has_many);
use Crypt::Eksblowfish::Bcrypt ();
use File::Path                 ();
use Mojo::Date;
use Mojo::Util 'trim';

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

sub core  { shift->{core}  or die 'core is required in constructor' }
sub email { shift->{email} or die 'email is required in constructor' }
sub password { shift->{password} ||= '' }
has unread => sub {0};

has_many connections => 'Convos::Core::Connection' => sub {
  my ($self, $attrs) = @_;
  Scalar::Util::weaken($attrs->{user} = $self);
  my $class = 'Convos::Core::Connection';

  if ($attrs->{protocol}) {
    my $protocol = Mojo::Util::camelize($attrs->{protocol} || '');
    $class = "Convos::Core::Connection::$protocol";
    eval "require $class;1" or die qq(Protocol "$attrs->{protocol}" is not supported: $@);
  }

  my $connection = $class->new($attrs);
  warn "[@{[$self->email]}] Emit connection for id=@{[$connection->id]}\n" if DEBUG;
  $self->core->backend->emit(connection => $connection);
  return $connection;
};

sub id { trim lc +($_[1] || $_[0])->{email} }

sub notifications {
  my ($self, $query, $cb) = @_;
  $self->core->backend->notifications($self, $query, $cb);
  $self;
}

sub remove_connection {
  my ($self, $id, $cb) = @_;
  my $connection = $self->{connections}{$id};

  unless ($connection) {
    Mojo::IOLoop->next_tick(sub { $self->$cb(''); });
    return $self;
  }

  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub { $connection->disconnect(shift->begin) },
    sub {
      my ($delay, $err) = @_;
      return $self->$cb($err) if $err;
      return $self->core->backend->delete_object($connection, $delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      delete $self->{connections}{$id} unless $err;
      $self->$cb($err);
    }
  );

  return $self;
}

sub save {
  my $self = shift;
  $self->core->backend->save_object($self, @_);
  $self;
}

sub set_password {
  die 'Usage: Convos::Core::User->set_password($plain)' unless $_[1];
  $_[0]->{password} = $_[0]->_bcrypt($_[1]);
  $_[0];
}

sub validate_password {
  my ($self, $plain) = @_;

  return 0 unless $self->password and $plain;
  return 1 if $self->_bcrypt($plain, $self->password) eq $self->password;
  return 0;
}

sub _bcrypt {
  my ($self, $plain, $settings) = @_;

  unless ($settings) {
    my $salt = join '', map { chr int rand 256 } 1 .. 16;
    $settings = BCRYPT_BASE_SETTINGS . Crypt::Eksblowfish::Bcrypt::en_base64($salt);
  }

  Crypt::Eksblowfish::Bcrypt::bcrypt($plain, $settings);
}

sub TO_JSON {
  my ($self, $persist) = @_;
  $self->{registered} ||= Mojo::Date->new->to_datetime;
  my $json = {map { ($_, $self->{$_} // '') } qw(email password registered)};
  delete $json->{password} unless $persist;
  $json->{unread} = $self->unread;
  $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::User - A Convos user

=head1 DESCRIPTION

L<Convos::Core::User> is a class used to model a user in Convos.

=head1 ATTRIBUTES

L<Convos::Core::User> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 core

  $obj = $self->core;

Holds a L<Convos::Core> object.

=head2 email

  $str = $self->email;

Email address of user.

=head2 password

  $str = $self->password;

Encrypted password. See L</set_password> for how to change the password and
L</validate_password> for password authentication.

=head2 unread

  $int = $self->unread;
  $self = $self->unread(4);

Number of unread notifications for user.

=head1 METHODS

L<Convos::Core::User> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connection

  $connection = $self->connection(\%attrs);

Returns a new L<Convos::Core::Connection> object or updates an existing object.

=head2 connections

  $objs = $self->connections;

Returns an array-ref of of L<Convos::Core::Connection> objects.

=head2 get_connection

  $connection = $self->connection($id);
  $connection = $self->connection(\%attrs);

Returns a L<Convos::Core::Connection> object or undef.

=head2 id

  $str = $self->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a user.

=head2 notifications

  $self = $self->notifications($query, sub { my ($self, $err, $notifications) = @_; });

Used to retrieve a list of notifications. See also
L<Convos::Core::Backend/notifications>.

=head2 remove_connection

  $self = $self->remove_connection($id, sub { my ($self, $err) = @_; });

Will remove a connection created by L</connection>. Removing a connection that
does not exist is perfectly valid, and will not set C<$err>.

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });
  $self = $self->save;

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 set_password

  $self = $self->set_password($plain);

Will set L</password> to a crypted version of C<$plain>.

=head2 validate_password

  $bool = $self->validate_password($plain);

Will verify C<$plain> text password against L</password>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
