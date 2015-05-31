package Convos::Model::Role::Memory;

=head1 NAME

Convos::Model::Role::Memory - Role for storing objects in memory

=head1 DESCRIPTION

L<Convos::Model::Role::Memory> contains methods which is useful for objects
that only want to be stored in memory.

=head1 SYNOPSIS

  package Some::Awesome::Model;
  use Role::Tiny::With;
  with "Convos::Model::Role::Memory";

  1;

=head1 ENVIRONMENT

=head2 CONVOS_SHARE_DIR

C<CONVOS_SHARE_DIR> can be set to specify where to save data from objects.
The default directory on *nix systems is something like this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=cut

use Mojo::Base -base;
use Mojo::Home;
use Mojo::JSON;
use Fcntl ':flock';
use File::Path ();
use File::Spec;
use Role::Tiny;

=head1 ATTRIBUTES

=cut

around _compose_classes_with => sub { my $orig = shift; ($orig->(@_), __PACKAGE__) };

=head1 METHODS

=head2 load

  $self = $self->load(sub { my ($self, $err) = @_; });

This method does nothing, since the object is not persisted to disk.

=cut

sub load {
  my ($self, $cb) = @_;
  $self->$cb('');
  $self;
}

=head2 save

  $self = $self->load(sub { my ($self, $err) = @_; });

This method does nothing, since the object is not persisted to disk.

=cut

sub save {
  my ($self, $cb) = @_;
  $self->$cb('');
  $self;
}

sub _find_connections { }
sub _find_users       { }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
