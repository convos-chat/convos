package Convos::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(false true);
use Mojo::Util;

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('auth.login'    => \&_login);
  $app->helper('auth.logout'   => \&_logout);
  $app->helper('auth.register' => sub { $self->_register(@_) });
}

sub _login {
  my ($c, $args, $cb) = @_;
  my $user = $c->app->core->get_user($args);

  if ($user and $user->validate_password($args->{password})) {
    $c->$cb('', $user);
  }
  else {
    $c->$cb('Invalid email or password.', undef);
  }
}

sub _logout {
  my ($c, $args, $cb) = @_;
  my $err = '';
  $c->$cb($err);
}

sub _register {
  my ($self, $c, $args, $cb) = @_;
  my $core = $c->app->core;
  my $user;

  if ($core->get_user($args)) {
    return $c->$cb('Email is taken.', '/body/email', undef);
  }

  $c->delay(
    sub {
      my ($delay) = @_;
      $user = $core->user($args);
      $user->set_password($args->{password});
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      $self->$cb($err, $user);
    },
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth - Convos plugin for handling authentication

=head1 DESCRIPTION

L<Convos::Plugin::Auth> is used to register, login and logout a user. This
plugin is always loaded by L<Convos>, but you can override the L</HELPERS>
with a custom auth plugin if you like.

Note that this plugin is currently EXPERIMENTAL. Let us know if you are/have
created a custom plugin.

=head1 HELPERS

=head2 auth.login

  $c->auth->login(\%credentials, sub { my ($c, $err, $user) = @_; });

Used to login a user. C<%credentials> normally contains an C<email> and
C<password>.

=head2 auth.logout

  $c->auth->logout({}, sub { my ($c, $err) = @_; });

Used to log out a user.

=head2 auth.register

  $c->auth->register(\%credentials, sub { my ($c, $err, $user) = @_; });

Used to register a user. C<%credentials> normally contains an C<email> and
C<password>.

=head1 METHODS

=head2 register

  $self->register($app, \%config);

=head1 SEE ALSO

L<Convos>

=cut
