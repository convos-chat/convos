package Convos::Model::Role::ClassFor;

=head1 NAME

Convos::Model::Role::ClassFor - A role for making new classes

=head1 DESCRIPTION

L<Convos::Model::Role::ClassFor> is a role which provide a C<_class_for()>
method which can generate new classes with properties similar to the C<$self>.

=head1 SYNOPSIS

  package Some::Awesome::Model;
  use Role::Tiny::With;
  with "Convos::Model::Role::ClassFor";

  # used by _class_for(), defined in Convos::Model::Role::File
  sub _compose_classes_with { "Convos::Model::Role::File" }

  sub new_object {
    my $self = shift;
    my $obj = $self->_class_for("Convos::SomeClass")->new;

    # $obj->isa("Convos::SomeClass")          == true
    # $obj->does("Convos::Model::Role::File") == true
  }

=cut

use Mojo::Base -base;
use Role::Tiny;

requires '_compose_classes_with';

sub _class_for {
  my ($self, $name) = @_;
  $self->{class_for}{$name} ||= do {
    eval "require $name;1" or die $@;
    Role::Tiny->create_class_with_roles($name, $self->_compose_classes_with);
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
