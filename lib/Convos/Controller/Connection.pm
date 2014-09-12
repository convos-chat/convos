package Convos::Controller::Connection;

=head1 NAME

Convos::Controller::Connection - Mojolicious controller for IRC connections

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw( as_id id_as pretty_server_name );

=head1 METHODS

=head2 add_connection

Add a new connection based on network name.

=cut

sub add_connection {
  my $self = shift;

  if ($self->req->method eq 'POST') {
    return $self->_add_connection;
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->conversation_list($delay->begin);
      $self->notification_list($delay->begin) if $self->stash('full_page');
    },
    sub {
      my ($delay) = @_;
      $self->render;
    },
  );
}

=head2 control

Used to control a connection. See L<Convos::Core/control>.

Special case is "state": It will return the state of the connection:
"disconnected", "error", "reconnecting" or "connected".

=cut

sub control {
  my $self        = shift;
  my $command     = $self->param('cmd') || 'state';
  my $name        = $self->stash('name');
  my $redirect_to = $self->url_for('view.network', {network => $name});

  $self->stash(layout => undef);

  if ($command eq 'state') {
    return $self->_connection_state(
      sub {
        $self->respond_to(json => {json => {state => $_[1]}}, any => {text => "$_[1]\n"},);
      }
    );
  }

  if ($self->req->method ne 'POST') {
    $self->_invalid_control_request;
  }
  elsif ($command =~ m!^/! or $command eq 'irc') {
    $self->delay(
      sub {
        my ($delay) = @_;
        my $key = sprintf 'convos:user:%s:%s', $self->session('login'), $name;
        $self->redis->publish($key => $self->param('irc_cmd') // $command, $delay->begin);
      },
      sub {
        my ($delay, $sent) = @_;
        $self->respond_to(
          json => {json => {state => $sent ? 'sent' : 'error'}, status => $sent ? 200 : 500},
          any => sub { shift->redirect_to($redirect_to) },
        );
      },
    );
  }
  else {
    $self->delay(
      sub {
        my ($delay) = @_;
        $self->app->core->control($command, $self->session('login'), $name, $delay->begin);
      },
      sub {
        my ($delay, $sent) = @_;
        my $status = $sent ? 200 : 500;
        my $state = $command eq 'stop' ? 'stopping' : "${command}ing";

        $self->respond_to(
          json => {json => {state => $state}, status => $status},
          any  => sub   { shift->redirect_to($redirect_to) },
        );
      },
    );
  }
}

=head2 edit_connection

Used to edit a connection.

=cut

sub edit_connection {
  my $self      = shift;
  my $full_page = $self->stash('full_page');
  my $method    = $self->req->method eq 'POST' ? '_edit_connection' : '_edit_connection_form';

  $self->delay(
    sub {
      my ($delay) = @_;

      $self->conversation_list($delay->begin);

      if ($full_page) {
        $self->_connection_state($delay->begin);
        $self->notification_list($delay->begin);
      }
    },
    sub {
      my ($delay, $state) = @_;

      $self->stash(network => $self->stash('name'), state => $state,);

      $self->$method;
    },
  );
}

=head2 delete_connection

Delete a connection.

=cut

sub delete_connection {
  my $self       = shift;
  my $validation = $self->validation;

  $validation->input->{login} = $self->session('login');
  $validation->input->{name}  = $self->stash('name');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->delete_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $error) = @_;
      return $self->render_not_found if $error;
      return $self->redirect_to('view.network', network => 'convos');
    }
  );
}

=head2 wizard

Render wizard page for first connection.

=cut

sub wizard {
  my $self  = shift;
  my $login = $self->session('login');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->srandmember("user:$login:connections", $delay->begin);
    },
    sub {
      my ($delay, $network) = @_;
      return $self->redirect_to('view.network', network => $network) if $network;
      return $self->render(layout => 'tactile', template => 'connection/wizard');
    },
  );
}

sub _add_connection {
  my $self       = shift;
  my $validation = $self->validation;

  $validation->input->{login} = $self->session('login');
  $validation->input->{name}  = pretty_server_name($self->param('server'));

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->add_connection($validation, $delay->begin);
      $self->notification_list($delay->begin) if $self->stash('full_page');
      $self->conversation_list($delay->begin);
    },
    sub {
      my ($delay, $errors, $conn) = @_;

      return $self->redirect_to('view.network', network => $conn->{name} || 'convos') unless $errors;
      return $self->param('wizard') ? $self->wizard : $self->render;
    },
  );
}

sub _connection_state {
  my ($self, $cb) = @_;
  my $login = $self->session('login');
  my $name  = $self->stash('name');

  $self->redis->hget("user:$login:connection:$name" => "state", sub { $cb->($_[0], $_[1] || 'disconnected') },);
}

sub _edit_connection {
  my $self       = shift;
  my $validation = $self->validation;
  my $full_page  = $self->stash('full_page');

  $validation->input->{login}  = $self->session('login');
  $validation->input->{name}   = $self->stash('name');
  $validation->input->{server} = $self->req->body_params->param('server');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->update_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $errors, $changed) = @_;
      return $self->_edit_connection_form if $errors;
      return $self->redirect_to('view.network', network => $self->stash('name'));
    }
  );
}

sub _edit_connection_form {
  my $self  = shift;
  my $login = $self->session('login');
  my $name  = $self->stash('name');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->_connection_state($delay->begin);
      $self->redis->hgetall("user:$login:connection:$name", $delay->begin) unless $self->req->method eq 'POST';
    },
    sub {
      my ($delay, $state, $connection) = @_;
      $self->param($_ => $connection->{$_}) for keys %$connection;
      $self->render(state => $state);
    },
  );
}

sub _invalid_control_request {
  shift->respond_to(json => {json => {}, status => 400}, any => {text => "Invalid request\n", status => 400},);
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
