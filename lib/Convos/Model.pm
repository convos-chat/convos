package Convos::Model;

=head1 NAME

Convos::Model - Convos Models

=head1 DESCRIPTION

L<Convos::Model> is a class which is used to set up defaults and connect
other Convos models.

=head1 SEE ALSO

=over 4

=item * L<Convos::Model::User>

=back

=head1 SYNOPSIS

  use Convos::Model;
  my $model = Convos::Model->new;
  my $user = $model->user($email);

=cut

use Mojo::Base -base;
use Mojo::Home;
use Cwd           ();
use File::HomeDir ();
use File::Path 'make_path';
use File::Spec;
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

our $VERSION = '0.01';

=head1 ATTRIBUTES

L<Convos::Model> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 share_dir

  $str = $self->share_dir;

Returns the location to where chat logs and user data is stored. This
can be set manually with the environment variable C<CONVOS_SHARE_DIR>.

Default is the ".local/share/convos" sub directory in L<File::HomeDir/my_home>.

=cut

has share_dir => sub {
  my $self = shift;
  my $path = $ENV{CONVOS_SHARE_DIR};

  unless ($path) {
    my $home = File::HomeDir->my_home
      || die 'Could not figure out CONVOS_SHARE_DIR. $HOME directory could not be found.';
    $path = File::Spec->catdir($home, qw( .local share convos ));
  }

  $path = Cwd::abs_path($path);
  warn "[CONVOS] share_dir=$path\n" if DEBUG;
  make_path $path unless -d $path;
  die "Cannot write to CONVOS_SHARE_DIR=$path\n" unless -w $path;
  return Mojo::Home->new($path);
};

=head1 METHODS

L<Convos::Model> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 user

  $user = $self->user($email);

Returns a L<Convos::Model::User> object.

=cut

sub user {
  my $self = shift;
  my $email = shift or die 'Usage: Convos::Model->user($email)';
  require Convos::Model::User;
  Convos::Model::User->new(home => File::Spec->catdir($self->share_dir, $email), @_, email => $email);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
