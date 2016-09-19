package Convos::Plugin::Helpers;
use Mojo::Base 'Convos::Plugin';

use Convos::Util 'E';

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('backend.dialog' => \&_backend_dialog);
  $app->helper('backend.user'   => \&_backend_user);
  $app->helper('unauthorized'   => \&_unauthorized);
}

sub _backend_dialog {
  my ($c, $args) = @_;
  my $user = $c->backend->user($args->{email}) or return;
  my $connection = $user->get_connection($args->{connection_id} || $c->stash('connection_id'))
    or return;
  my $dialog = $connection->get_dialog($args->{dialog_id} || $c->stash('dialog_id'));

  $c->stash(connection => $connection, dialog => $dialog);

  return $dialog;
}

sub _backend_user {
  my $c = shift;
  return undef unless my $email = shift || $c->session('email');
  return $c->app->core->get_user({email => $email});
}

sub _unauthorized {
  shift->render(json => E('Need to log in first.'), status => 401);
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Helpers - Default helpers for Convos

=head1 DESCRIPTION

This L<Convos::Plugin> contains default helpers for L<Convos>.

=head1 HELPERS

=head2 backend.dialog

  $dialog = $c->backend->dialog(\%args);

Helper to retrieve a L<Convos::Core::Dialog> object. Will use
data from C<%args> or fall back to L<stash|Mojolicious/stash>. Example
C<%args>:

  {
    # Key         => Example value        # Default value
    connection_id => "irc-localhost",     # $c->stash("connection_id")
    dialog_id     => "#superheroes",      # $c->stash("connection_id")
    email         => "superwoman@dc.com", # $c->session('email')
  }

=head2 backend.user

  $user = $c->backend->user($email);
  $user = $c->backend->user;

Used to return a L<Convos::User> object representing the logged in user
or a user with email C<$email>.

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
