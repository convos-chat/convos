package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';

sub delete {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  if (@{$self->app->core->users} <= 1) {
    return $self->render(openapi => E('You are the only user left.'), status => 400);
  }

  $self->delay(
    sub { $self->app->core->backend->delete_object($user, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      delete $self->session->{email};
      $self->render(openapi => {message => 'You have been erased.'});
    },
  );
}

sub get {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  $self->delay(
    sub { $user->get($self->req->url->query->to_hash, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      die $err if $err;
      $self->render(openapi => $res);
    }
  );
}

sub login {
  my $self = shift->openapi->valid_input or return;

  $self->delay(
    sub { $self->auth->login($self->req->json, shift->begin) },
    sub {
      my ($delay, $err, $user) = @_;
      return $self->render(openapi => E($err), status => 400) if $err;
      return $self->session(email => $user->email)->render(openapi => $user);
    },
  );
}

sub logout {
  my $self = shift;

  $self->delay(
    sub { $self->auth->logout({}, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      return $self->render(openapi => E($err), status => 400) if $err;
      return $self->session({expires => 1})->redirect_to('index');
    },
  );
}

sub register {
  my $self = shift->openapi->valid_input or return;

  $self->delay(
    sub { $self->auth->register($self->req->json, shift->begin) },
    sub {
      my ($delay, $err, $user) = @_;
      return $self->render(openapi => E($err), status => 400) if $err;
      return $self->session(email => $user->email)->render(openapi => $user);
    },
  );
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->req->json;
  my $user = $self->backend->user or return $self->unauthorized;

  # TODO: Add support for changing email

  unless (%$json) {
    return $self->render(openapi => $user);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $user->set_password($json->{password}) if $json->{password};
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(openapi => $user);
    },
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::User - Convos user actions

=head1 DESCRIPTION

L<Convos::Controller::User> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 delete

See L<Convos::Manual::API/deleteUser>.

=head2 get

See L<Convos::Manual::API/getUser>.

=head2 login

See L<Convos::Manual::API/loginUser>.

=head2 logout

See L<Convos::Manual::API/logoutUser>.

=head2 register

See L<Convos::Manual::API/registerUser>.

=head2 update

See L<Convos::Manual::API/updateUser>.

=head1 SEE ALSO

L<Convos>.

=cut
