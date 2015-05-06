package Convos;

=head1 NAME

Convos - Multiuser chat application

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Convos> is a multiuser chat application built with L<Mojolicious>.

It currently support the IRC protocol, but can be extended to support
other protocols as well.

=head1 SYNOPSIS

You can start convos by running one of the commands below.

  $ convos daemon;
  $ convos daemon --listen http://*:3000;

You can then visit Convos in your browser, by going to the default
address L<http://localhost:3000>.

=head1 SEE ALSO

=over 4

=item * L<Convos::Manual::API>

=back

=cut

use Mojo::Base 'Mojolicious';
use Convos::Model;
use Swagger2::Editor;

our $VERSION = '0.01';

=head1 ATTRIBUTES

L<Convos> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 model

Holds a L<Convos::Model> object.

=cut

has model => sub { Convos::Model->new };

=head1 METHODS

L<Convos> inherits all methods from L<Mojolicious> and implements
the following new ones.

=head2 startup

This method set up the application.

=cut

sub startup {
  my $self         = shift;
  my $swagger_file = $self->home->rel_file('public/api.json');

  $self->plugin(Swagger2 => {url => $swagger_file});
  $self->routes->route('/spec')->detour(app => Swagger2::Editor->new(specification_file => $swagger_file));
  $self->routes->get('/')->to(template => 'app');
  push @{$self->renderer->classes}, __PACKAGE__;
  $self->model->share_dir;    # make sure we have a valid share_dir
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

__DATA__
@@ app.html.ep
<!DOCTYPE html>
<html>
</html>
