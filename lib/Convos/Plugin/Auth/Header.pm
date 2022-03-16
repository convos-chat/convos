package Convos::Plugin::Auth::Header;
use Mojo::Base 'Convos::Plugin::Auth', -async_await;

has admin_user         => sub { $ENV{CONVOS_ADMIN} // 'admin-email-not-set@example.com' };
has x_user_header_name => sub { $ENV{CONVOS_AUTH_HEADER} || 'X-Authenticated-User' };

sub register {
  my ($self, $app, $config) = @_;
  $self->SUPER::register($app, $config);
  $self->admin_user($config->{admin_user})                 if defined $config->{admin_user};
  $self->x_user_header_name($config->{x_user_header_name}) if $config->{x_user_header_name};
  $app->helper('user.load_p' => sub { $self->_user_load_p(@_) });
}

async sub _user_load_p {
  my ($self, $c) = @_;
  my $core = $c->app->core;

  my $header = $self->x_user_header_name;
  my $email  = $c->req->headers->header($header);
  return _giveup($c, debug => "Header $header is missing in request.") unless $email;

  my $user = $email && $core->get_user({email => $email});
  return $c->stash->{user} = $user if $user;

  if (!$core->n_users and $self->admin_user and $email ne $self->admin_user) {
    my $admin = $self->admin_user;
    return _giveup($c, warn => "Cannot auto-register user, when admin $admin is not registered.");
  }

  $c->app->log->info("Auto-registering user $email from header $header");
  return $c->stash->{user} = await $core->user({email => $email})->save_p;
}

sub _giveup {
  my ($c, $level, $msg) = @_;
  $c->log->$level($msg);
  return undef;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth::Header - Authenticate users by verifying reverse proxy header

=head1 SYNOPSIS

  $ CONVOS_PLUGINS=Convos::Plugin::Auth::Header \
    CONVOS_ADMIN=admin@example.com \
    CONVOS_AUTH_HEADER=X-User \
    ./script/convos daemon

C<CONVOS_ADMIN> defaults to C<admin-email-not-set@example.com>, but can be set
to the Convos admin user's email address to I<disallow> anyone else to register
as a normal user before the admin has registered/logged in. Setting this
enviroment variable to an empty string will make the first user the admin user.

C<CONVOS_AUTH_HEADER> must contain the header name that will contain the email
address of the logged in user. The default value is "X-Authenticated-User", but
can be set to "X-User" or any value you like. Do make sure though that this
header cannot be set from user request!

=head1 DESCRIPTION

L<Convos::Plugin::Auth::Header> is used to register and login users based on a
header set in a reverse proxy web server, such as nginx.

=head1 HELPERS

=head2 user.load_p

  $user = await $c->user->load_p;

See L<Convos::Plugin::Auth/user.load_p> for details.

=head1 METHODS

=head2 register

  $auth->register($app, \%config);

=head1 SEE ALSO

L<Convos::Plugin::Auth>, L<Convos>.

=cut
