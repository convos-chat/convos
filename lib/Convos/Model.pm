package Convos::Model;

=head1 NAME

Convos::Model - Convos Models

=head1 DESCRIPTION

L<Convos::Model> is a class which is used to instantiate other model objects
with proper defaults.

=head1 SYNOPSIS

  use Convos::Model;
  my $model = Convos::Model->new;
  my $user = $model->user($email);

=head1 SEE ALSO

=over 4

=item * L<Convos::Model::User>

=back

=cut

use Mojo::Base -base;
use Cwd           ();
use File::HomeDir ();
use File::Spec;
use Role::Tiny::With;

with 'Convos::Model::Role::ClassFor';

=head1 ATTRIBUTES

L<Convos::Model> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head1 METHODS

L<Convos::Model> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 new_with_backend

  $self = Convos::Model->new_with_backend($backend => %attrs);
  $self = Convos::Model->new_with_backend($backend => \%attrs);

Will create a new object with a given C<$backend>. Supported backends are
currently:

=over 4

=item * L<Convos::Model::Role::File>

=item * L<Convos::Model::Role::Memory>

=back

=cut

sub new_with_backend {
  my ($class, $backend) = (shift, shift);
  $backend = "Convos::Model::Role::$backend" unless $backend =~ /::/;
  my $self = Role::Tiny->create_class_with_roles($class, $backend)->new(@_);
  $self->{backend} = $backend;
  $self;
}

=head2 user

  $user = $self->user(%attrs);

Returns a L<Convos::Model::User> object.

=cut

sub user {
  my $self = shift;
  $self->_class_for('Convos::Model::User')->new(@_);
}

sub _compose_classes_with { }
sub _setting_keys         { }
sub _sub_dir              { }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
