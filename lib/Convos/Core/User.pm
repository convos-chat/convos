package Convos::Core::User;

=head1 NAME

Convos::Core::User - A Convos user

=head1 DESCRIPTION

L<Convos::Core::User> is a class used to model a user in Convos.

=cut

use Mojo::Base -base;
use File::Path                 ();
use Crypt::Eksblowfish::Bcrypt ();
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

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

  $connection = $self->connection($type => $name);

Returns a connection object. Every new object created will emit
a "connection" event:

  $self->core->backend->emit(connection => $connection);

C<$type> should be the type of the connection class. Example "IRC" will be
translated to L<Convos::Core::Connection::IRC>.

=cut

sub connection {
  my ($self, $type, $name) = @_;

  die "Invalid name $name. Need to match /^[\\w-]+\$/" unless $name and $name =~ /^[\w-]+$/;
  $name = lc $name;
  $self->{connections}{$type}{$name} ||= do {
    my $connection_class = "Convos::Core::Connection::$type";
    eval "require $connection_class;1" or die $@;
    my $connection = $connection_class->new(name => $name, user => $self);
    Scalar::Util::weaken($connection->{user});
    warn "[Convos::Core::User] Emit connection name=$name\n" if DEBUG;
    $self->core->backend->emit(connection => $connection);
    $connection;
  };
}

=head2 load

  $self = $self->load(sub { my ($self, $err) = @_; });

Will load L</ATTRIBUTES> from persistent storage.
See L<Convos::Core::Backend/load_object> for details.

=cut

sub load {
  my $self = shift;
  $self->core->backend->load_object($self, @_);
  $self;
}

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });

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

sub _path { shift->email }

sub TO_JSON {
  my ($self, $all) = @_;
  $self->{registered} ||= time;
  my $json = {map { ($_, $self->{$_}) } qw( avatar email password registered )};
  delete $json->{password} unless $all;
  return $json;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
