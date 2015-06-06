package Convos::Controller::User;

=head1 NAME

Convos::Controller::User - Convos user actions

=head1 DESCRIPTION

L<Convos::Controller::User> is a L<Mojolicious::Controller> with
user related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 user

See L<Convos::Manual::API/user>.

=cut

sub user {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->_unauthorized($cb);

  $self->$cb($user->TO_JSON, 200);
}

=head2 user_authenticate

See L<Convos::Manual::API/userAuthenticate>.

=cut

sub user_authenticate {
  my ($self, $args, $cb) = @_;
  my $user = $self->app->core->user($args->{data}{email});

  if ($user->validate_password($args->{data}{password})) {
    $self->session(email => $user->email)->$cb($user->TO_JSON, 200);
  }
  else {
    $self->$cb($self->invalid_request('Invalid email or password.'), 400);
  }
}

=head2 user_delete

See L<Convos::Manual::API/userDelete>.

=cut

sub user_delete {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->_unauthorized($cb);

  $self->delay(
    sub { $self->app->core->backend->find_users(shift->begin); },
    sub {
      my ($delay, $err, $users) = @_;
      die $err if $err;
      return $delay->pass('Delete user is not implemented.') if @$users > 1;
      return $self->$cb($self->invalid_request('You are the only user left.'), 400);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      delete $self->session->{email};
      $self->$cb({message => 'User deleted.'}, 200);
    },
  );
}

=head2 user_register

See L<Convos::Manual::API/userRegister>.

=cut

sub user_register {
  my ($self, $args, $cb) = @_;
  my $user = $self->app->core->user($args->{data}{email});

  # TODO: Add support for invite code

  if ($user->password) {
    return $self->$cb($self->invalid_request('Email is taken.', '/data/email'), 409);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->user($args->{data}{email}, {avatar => $args->{data}{avatar} || ''});
      $user->set_password($args->{data}{password});
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->session(email => $user->email)->$cb($user->TO_JSON, 200);
    },
  );
}

=head2 user_save

See L<Convos::Manual::API/userSave>.

=cut

sub user_save {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->_unauthorized($cb);

  # TODO: Add support for changing email

  $user->avatar($args->{data}{avatar})         if $args->{data}{avatar};
  $user->set_password($args->{data}{password}) if $args->{data}{password};

  $self->delay(
    sub {
      my ($delay) = @_;
      return $delay->pass unless %{$args->{data}};
      return $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->$cb($user->TO_JSON, 200);
    },
  );
}

sub _unauthorized {
  my ($self, $cb) = @_;
  return $self->$cb($self->invalid_request('Need to log in first.', '/X-Convos-Session'), 401);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
