package Convos::Core::User;

=head1 NAME

Convos::Core::User - A Convos user

=head1 DESCRIPTION

L<Convos::Core::User> is a class used to model a user in Convos.

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Date;
use Mojo::Util;
use Convos::Core::Connection;
use Crypt::Eksblowfish::Bcrypt ();
use File::Path                 ();
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

sub EVENTS {qw( conversation me message state users )}

=head1 ATTRIBUTES

L<Convos::Core::User> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 avatar

  $str = $self->avatar;
  $self = $self->avatar($str);

Avatar identifier on either Facebook or Gravatar.

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

=cut

has avatar => '';
sub core  { shift->{core}  or die 'core is required in constructor' }
sub email { shift->{email} or die 'email is required in constructor' }
sub password { shift->{password} ||= '' }

=head1 METHODS

L<Convos::Core::User> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connection

  $connection = $self->connection($id);          # get
  $connection = $self->connection(\%connection); # add

Returns a connection object. Every new object created will emit
a "connection" event:

  $self->emit(connection => $connection);

=cut

sub connection {
  my ($self, $obj) = @_;

  # Get
  return $self->{connections}{$obj} unless ref $obj;

  # Add
  $obj->{user} = $self;
  $obj = Convos::Core::Connection->new($obj) if ref $obj eq 'HASH';

  die 'Connection already exists.' if $self->{connections}{$obj->id};
  $self->{connections}{$obj->id} = $obj;

  Scalar::Util::weaken($self);
  for my $e ($self->EVENTS) {
    $obj->on($e => sub { $self->emit($e => @_) });
  }

  warn "[@{[$self->email]}] Emit connection for id=@{[$obj->id]}\n" if DEBUG;
  $self->core->backend->emit(connection => $obj);
  return $obj;
}

=head2 connections

  $objs = $self->connections;

Returns an array-ref of of L<Convos::Core::Connection> objects.

=cut

sub connections { [values %{$_[0]->{connections} || {}}] }

=head2 remove_connection

  $self = $self->remove_connection($id, sub { my ($self, $err) = @_; });

Will remove a connection created by L</connection>. Removing a connection that
does not exist is perfectly valid, and will not set C<$err>.

=cut

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

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });
  $self = $self->save;

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=cut

sub save {
  my $self = shift;
  $self->core->backend->save_object($self, @_);
  $self;
}

=head2 set_password

  $self = $self->set_password($plain);

Will set L</password> to a crypted version of C<$plain>.

=cut

sub set_password {
  die 'Usage: Convos::Core::User->set_password($plain)' unless $_[1];
  $_[0]->{password} = $_[0]->_bcrypt($_[1]);
  $_[0];
}

=head2 validate_password

  $bool = $self->validate_password($plain);

Will verify C<$plain> text password against L</password>.

=cut

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

sub INFLATE {
  my ($self, $attrs) = @_;
  $self->{$_} = $attrs->{$_} for keys %$attrs;
  $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  $self->{registered} ||= Mojo::Date->new->to_datetime;
  my $json = {map { ($_, $self->{$_} // '') } qw( avatar email password registered )};
  delete $json->{password} unless $persist;
  $json;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
