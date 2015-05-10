package Convos::Model::Connection;

=head1 NAME

Convos::Model::Connection - A Convos connection base class

=head1 DESCRIPTION

L<Convos::Model::Connection> is a base class for L<Convos> connections.

See also L<Convos::Model::Connection::IRC>.

=head1 SYNOPSIS

  use Convos::Model::Connection::YourConnection;
  use Mojo::Base "Convos::Model::Connection";
  # ...
  1;

=cut

use Mojo::Base 'Mojo::EventEmitter';

=head1 ATTRIBUTES

L<Convos::Model::Connection> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 name

Holds the name of the connection.
Need to be unique per L<user|Convos::Model::User>.

=cut

has name => sub { die 'name is required' };

=head1 METHODS

L<Convos::Model::Connection> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=cut

sub TO_JSON {
  my $self = shift;
  return {map { ($_, $_[0]->{$_}) } $self->_setting_keys};
}

sub _setting_keys { }
sub _sub_dir { File::Spec->catdir('connection', shift->name) }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
