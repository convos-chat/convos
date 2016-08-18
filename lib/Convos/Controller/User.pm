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
  my $res  = $user->TO_JSON;
  my (@connections, @dialogs);

  if ($self->param('connections') or $self->param('dialogs')) {
    @connections = sort { $a->name cmp $b->name } @{$user->connections};
  }
  if ($self->param('dialogs')) {
    for my $connection (@connections) {
      @dialogs = sort { $a->id cmp $b->id } @{$connection->dialogs};
    }
    $res->{dialogs} = \@dialogs;
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      return $delay->pass unless $self->param('notifications');
      return $user->notifications({}, $delay->begin);
    },
    sub {
      my ($delay, $err, $notifications) = @_;
      die $err if $err;
      $res->{connections}   = \@connections  if $self->param('connections');
      $res->{notifications} = $notifications if $notifications;
      $self->render(openapi => $res);
    }
  );
}

sub login {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->req->json;
  my $user = $self->app->core->get_user($json);

  if ($user and $user->validate_password($json->{password})) {
    $self->session(email => $user->email)->render(openapi => $user);
  }
  else {
    $self->render(openapi => E('Invalid email or password.'), status => 400);
  }
}

sub logout {
  shift->session({expires => 1})->redirect_to('index');
}

sub register {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->req->json;
  my $core = $self->app->core;
  my $user;

  if (my $invite_code = $self->app->config('invite_code')) {
    if (!$json->{invite_code} or $json->{invite_code} ne $invite_code) {
      return $self->render(openapi => E('Invalid invite code.', '/body/invite_code'),
        status => 400);
    }
  }
  if ($core->get_user($json)) {
    return $self->render(openapi => E('Email is taken.', '/body/email'), status => 409);
  }

  return $self->delay(
    sub {
      my ($delay) = @_;
      $user = $core->user($json);
      $user->set_password($json->{password});
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->session(email => $user->email)->render(openapi => $user);
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
