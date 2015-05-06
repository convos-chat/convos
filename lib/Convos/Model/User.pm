package Convos::Model::User;

=head1 NAME

Convos::Model::User - A Convos user

=head1 DESCRIPTION

L<Convos::Model::User> is a class used to model a user in Convos.

=head1 SYNOPSIS

  use Convos::Model::User;
  my $user = Convos::Model::User->new;

=cut

use Mojo::Base -base;
use Mojo::JSON;
use Crypt::Eksblowfish::Bcrypt ();
use File::Path                 ();
use File::Spec;

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

my @SETTING_KEYS = qw( avatar email password );

=head1 ATTRIBUTES

L<Convos::Model::User> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 avatar

Avatar identifier on either Facebook or Gravatar.

=head2 email

Email address of user.

=head2 home

Path to where the user store settings and logs.

=head2 password

Encrypted password.

=cut

has avatar   => '';
has email    => sub { die 'email is required' };
has home     => sub { die 'home is required' };
has password => '';

=head1 METHODS

L<Convos::Model::User> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 load

  $self = $self->load(sub { my ($self, $err) = @_; });

Used to load user settings from persistent storage. C<$err> is not set if
if the user is not saved.

=cut

sub load {
  my ($self, $cb) = @_;
  my $settings_file = File::Spec->catfile($self->home, 'settings.json');
  my $settings = {};

  $cb ||= sub { die $_[1] if $_[1] };

  if (-e $settings_file) {
    eval {
      $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($settings_file));
      $self->{$_} = $settings->{$_} for grep { defined $settings->{$_} } @SETTING_KEYS;
      1;
    } or do {
      $self->$cb($@);
      return $self;
    };
  }

  $self->$cb('');
  $self;
}

=head2 save

  $self = $self->load(sub { my ($self, $err) = @_; });

Used to save user settings to persistent storage.

=cut

sub save {
  my ($self, $cb) = @_;
  my $settings_file = File::Spec->catfile($self->home, 'settings.json');

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    File::Path::make_path($self->home) unless -d $self->home;
    Mojo::Util::spurt(Mojo::JSON::encode_json({map { ($_, $_[0]->{$_}) } @SETTING_KEYS}), $settings_file);
    $self->$cb('');
    1;
  } or do {
    $self->$cb($@);
  };

  return $self;
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
  my $json = {map { ($_, $_[0]->{$_}) } @SETTING_KEYS};
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

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
