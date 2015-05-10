package Convos::Model::Connection::IRC;

=head1 NAME

Convos::Model::Connection::IRC - IRC connection for Convos

=head1 DESCRIPTION

L<Convos::Model::Connection::IRC> is a connection class for L<Convos> which
allow you to communicate over the IRC protocol.

=cut

no warnings 'utf8';
use Mojo::Base 'Convos::Model::Connection';
use Mojo::IRC;
use Parse::IRC ();
use Time::HiRes 'time';

=head1 ATTRIBUTES

L<Convos::Model::Connection::IRC> inherits all attributes from L<Convos::Model::Connection>
and implements the following new ones.

=cut

=head1 METHODS

L<Convos::Model::Connection::IRC> inherits all methods from L<Convos::Model::Connection>
and implements the following new ones.

=cut

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
