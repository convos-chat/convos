package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'ce';

sub command {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id});

  unless ($connection) {
    return $self->$cb(ce 'Connection not found.', '/connection_id', 404);
  }

  $self->delay(
    sub { $connection->send($args->{dialog_id}, $args->{command}, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      $res = $res->TO_JSON if UNIVERSAL::can($res, 'TO_JSON');
      $res->{command} = $args->{command};
      return $self->$cb({data => $res}) unless $err;
      return $self->$cb(ce $err, '/', 500);
    },
  );
}

sub delete {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  if (@{$self->app->core->users} <= 1) {
    return $self->$cb(ce 'You are the only user left.', '/', 400);
  }

  $self->delay(
    sub { $self->app->core->backend->delete_object($user, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      delete $self->session->{email};
      $self->$cb({data => {message => 'You have been erased.'}});
    },
  );
}

sub get {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  $self->$cb({data => $user->TO_JSON});
}

sub login {
  my ($self, $args, $cb) = @_;
  my $user = $self->app->core->get_user($args);

  if ($user and $user->validate_password($args->{password})) {
    $self->session(email => $user->email)->$cb({data => $user->TO_JSON});
  }
  else {
    $self->$cb(ce 'Invalid email or password.', '/email', 400);
  }
}

sub logout {
  shift->session({expires => 1})->redirect_to('index');
}

sub register {
  my ($self, $args, $cb) = @_;
  my $core = $self->app->core;
  my $user;

  if (my $invite_code = $self->app->config('invite_code')) {
    if (!$args->{invite_code} or $args->{invite_code} ne $invite_code) {
      return $self->$cb($self->invalid_request('Invalid invite code.', '/body/invite_code'), 400);
    }
  }
  if ($core->get_user($args)) {
    return $self->$cb($self->invalid_request('Email is taken.', '/body/email'), 409);
  }

  return $self->delay(
    sub {
      my ($delay) = @_;
      $user = $core->user($args);
      $user->set_password($args->{password});
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->session(email => $user->email)->$cb($user->TO_JSON, 200);
    },
  );
}

sub update {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  # TODO: Add support for changing email

  unless (%{$args || {}}) {
    return $self->$cb($user->TO_JSON, 200);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $user->set_password($args->{password}) if $args->{password};
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->$cb($user->TO_JSON, 200);
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

=head2 command

=head2 delete

=head2 get

=head2 login

=head2 logout

=head2 register

=head2 update

=head1 SEE ALSO

L<Convos>

=cut
