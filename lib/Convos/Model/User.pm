package Convos::Model::User;

=head1 NAME

Convos::Model::User - A Convos user

=head1 DESCRIPTION

L<Convos::Model::User> is a class used to model a user in Convos.

=head1 SYNOPSIS

  use Convos::Model;
  my $user = Convos::Model->new->user("jhthorsen@cpan.org");

  $user->set_password("s3cret");
  $user->save;

=cut

use Mojo::Base -base;
use File::Path                 ();
use Crypt::Eksblowfish::Bcrypt ();
use Role::Tiny::With;

with 'Convos::Model::Role::ClassFor';

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

=head1 ATTRIBUTES

L<Convos::Model::User> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 avatar

Avatar identifier on either Facebook or Gravatar.

=head2 email

Email address of user.

=head2 password

Encrypted password.

=cut

has avatar   => '';
has email    => sub { die 'email is required' };
has password => '';

=head1 METHODS

L<Convos::Model::User> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connection

  $connection = $self->connection($type => $name);

Returns a connection object. C<$type> can either be a class name
or a class moniker:

  .-----------------------------------------------------------------.
  | $type                          | Resolved class name            |
  |--------------------------------|--------------------------------|
  | IRC                            | Convos::Model::Connection::IRC |
  | Convos::Model::Connection::IRC | Convos::Model::Connection::IRC |
  '-----------------------------------------------------------------'

=cut

sub connection {
  my ($self, $type, $name) = @_;

  die "Invalid name $name. Need to match /^[\\w_-]+\$/" unless $name and $name =~ /^[\w_-]+$/;
  $name = lc $name;
  $type = "Convos::Model::Connection::$type" unless $type =~ /::/;
  $self->{connections}{$type}{$name} ||= do {
    my $connection = $self->_class_for($type)->new(name => $name, user => $self);
    Scalar::Util::weaken($connection->{user});
    $connection;
  };
}

=head2 set_password

  $self = $self->set_password($plain);

Used to set L</password> to a crypted version of C<$plain>.

=cut

sub set_password {
  die 'Usage: Convos::Model::User->set_password($plain)' unless $_[1];
  $_[0]->password($_[0]->_bcrypt($_[1]));
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

sub TO_JSON {
  my $self = shift;
  my $json = {map { ($_, $self->{$_}) } $self->_setting_keys};
  delete $json->{password};
  return $json;
}

sub _bcrypt {
  my ($self, $plain, $settings) = @_;

  unless ($settings) {
    my $salt = join '', map { chr int rand 256 } 1 .. 16;
    $settings = BCRYPT_BASE_SETTINGS . Crypt::Eksblowfish::Bcrypt::en_base64($salt);
  }

  Crypt::Eksblowfish::Bcrypt::bcrypt($plain, $settings);
}

sub _build_home { Mojo::Home->new($_[0]->{model}->home->rel_dir($_[0]->email)) }
sub _compose_classes_with { }    # will get role names from around modifiers

sub _setting_keys {
  $_[0]->{registered} ||= time;
  qw( avatar email password registered );
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
