package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

sub command {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{body}{connection_id});

  unless ($connection) {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  }

  $self->delay(
    sub { $connection->send($args->{body}{dialog_id}, $args->{body}{command}, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      $res = $res->TO_JSON if UNIVERSAL::can($res, 'TO_JSON');
      $res->{command} = $args->{body}{command};
      return $self->$cb($res, 200) unless $err;
      return $self->$cb($self->invalid_request($err), 500);
    },
  );
}

sub delete {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  if (@{$self->app->core->users} <= 1) {
    return $self->$cb($self->invalid_request('You are the only user left.'), 400);
  }

  $self->delay(
    sub { $self->app->core->backend->delete_object($user, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      delete $self->session->{email};
      $self->$cb({message => 'You have been erased.'}, 200);
    },
  );
}

sub get {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  $self->$cb($user->TO_JSON, 200);
}

sub login {
  my ($self, $args, $cb) = @_;
  my $user = $self->app->core->get_user($args->{body});

  if ($user and $user->validate_password($args->{body}{password})) {
    $self->session(email => $user->email)->$cb($user->TO_JSON, 200);
  }
  else {
    $self->$cb($self->invalid_request('Invalid email or password.'), 400);
  }
}

sub logout {
  my ($self, $args, $cb) = @_;
  $self->session({expires => 1});
  $self->$cb({}, 200);
}

sub register {
  my ($self, $args, $cb) = @_;
  my $core = $self->app->core;
  my $user = $core->get_user($args->{body});

  # TODO: Add support for invite code

  return $self->$cb($self->invalid_request('Registration is closed.', '/'), 400)
    if $self->app->config('disable_registration');
  return $self->$cb($self->invalid_request('Email is taken.', '/body/email'), 409) if $user;
  return $self->delay(
    sub {
      my ($delay) = @_;
      $user = $core->user($args->{body});
      $user->set_password($args->{body}{password});
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

  unless (%{$args->{body} || {}}) {
    return $self->$cb($user->TO_JSON, 200);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $user->set_password($args->{body}{password}) if $args->{body}{password};
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

See L<Convos::Manual::API/commandFromUser>.

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

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
