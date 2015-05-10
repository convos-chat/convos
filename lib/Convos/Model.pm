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
use Role::Tiny ();

=head1 ATTRIBUTES

L<Convos::Model> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 backend

The name of a L<role|Role::Tiny> which is used to store data persistently.
Default to L<Convos::Model::Role::File>.

This attribute is read-only.

=cut

sub backend {
  $_[0]->{backend} ||= do { require Convos::Model::Role::File; 'Convos::Model::Role::File' }
}

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
  $self->_class_for('Convos::Model::User')->new(@_, email => $email);
}

sub _class_for {
  my ($self, $name) = @_;
  $self->{class_for}{$name} ||= do {
    eval "require $name;1" or die $@;
    Role::Tiny->create_class_with_roles($name, $self->backend);
  };
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
