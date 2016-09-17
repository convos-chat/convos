package Convos::Plugin::Helpers;
use Mojo::Base 'Convos::Plugin';

use Convos::Util 'E';

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('backend.user' => \&_backend_user);
  $app->helper('unauthorized' => \&_unauthorized);
}

sub _backend_user {
  my $c = shift;
  return undef unless my $email = $c->session('email');
  return $c->app->core->get_user({email => $email});
}

sub _unauthorized {
  shift->render(openapi => E('Need to log in first.'), status => 401);
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Helpers - Default helpers for Convos

=head1 DESCRIPTION

This L<Convos::Plugin> contains default helpers for L<Convos>.

=head1 HELPERS

=head2 backend.user

  $user = $c->backend->user;

Used to return a L<Convos::User> object representing the logged in user.

=head2 unauthorized

  $c = $c->unauthorized;

Used to render an OpenAPI response with status code 401.

=head1 METHODS

=head2 register

  $self->register($app, \%config);

Called by L<Convos>, when registering this plugin.

=head1 SEE ALSO

L<Convos>.

=cut
