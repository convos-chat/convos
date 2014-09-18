package Convos::Controller::User;

=head1 NAME

Convos::Controller::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw( as_id id_as pretty_server_name );
use Mojo::Asset::File;
use Mojo::Date;
use Mojo::Util 'md5_sum';
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;

my $KIOSK_USER = 1;

=head1 METHODS

=head2 auth

Check authentication and login

=cut

sub auth {
  my $self = shift;

  if ($self->session('login')) {
    return 1;
  }
  elsif ($self->req->url->path =~ /\.json$/) {
    $self->render(json => {}, status => 403);
  }
  else {
    $self->redirect_to('/');
  }

  return 0;
}

=head2 kiosk

Used to chat with a temporay profile. Example URL:

=cut

sub kiosk {
  my $self  = shift;
  my $login = $self->session('login');
  my $input = $self->validation->input;

  if ($login) {
    return $self->redirect_to('/');
  }
  if (!$input or !%$input) {
    return $self->render(layout => 'tactile');
  }

  $login = sprintf 'kiosk:%s:%s:%s', time, $$, ++$KIOSK_USER;
  $input->{email} ||= "$login\@kiosk.convos.by";
  $input->{nick}  ||= Convos::Core::Util::random_name();
  $input->{login}          = $login;
  $input->{name}           = pretty_server_name($input->{server}) if $input->{server};
  $input->{password}       = md5_sum $self->session->{login} . rand 1000;
  $input->{password_again} = $input->{password};
  $input->{username}       = md5_sum $self->tx->remote_address;                          # make it easier to ban a user

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->add_user($self->validation, $delay->begin);
    },
    sub {
      my ($delay, $validation, $user) = @_;
      return $self->render_exception('Generated kiosk mode user values failed.') if $validation;
      return $self->app->core->add_connection($self->validation, $delay->begin);
    },
    sub {
      my ($delay, $validation, $conn) = @_;
      warn Data::Dumper::Dumper($validation);

      # TODO: What to do on error?
      return $self->render_exception('Generated kiosk mode connection values failed.') if $validation;
      $self->session(login => $login, kiosk => 1);
      $self->redirect_to('view.network', network => $conn->{name} || 'convos');
    },
  );
}

=head2 login

Show the login form. Also responds to JSON requests with login status.

=cut

sub login {
  my $self = shift;

  unless ($self->app->config->{redis_version}) {
    return $self->delay(
      sub {
        my ($delay) = @_;
        $self->redis->info(server => $delay->begin);
      },
      sub {
        my ($delay, $server_info) = @_;
        my $app = $self->app;
        $app->config->{redis_version} = $server_info =~ /redis_version:(\d+\.\d+)/ ? $1 : '0e0';
        $app->log->info("Redis server version: @{[$app->config->{redis_version}]}");
        $self->login;
      },
    );
  }

  $self->stash(form => 'login');

  if ($self->session('login')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    return $self->redirect_to('view');
  }
  if ($self->req->method ne 'POST') {
    return $self->respond_to(html => {template => 'index'}, json => {json => {login => $self->session('login') || ''}});
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->login($self->validation, $delay->begin);
    },
    sub {
      my ($delay, $error) = @_;
      return $self->render('index', status => 401) if $error;
      my $login = $self->validation->param('login');
      $self->session(login => $login);
      $self->respond_to(html => sub { $self->redirect_last($login) }, json => {json => {login => $login}});
    },
  );
}

=head2 register

See L</login>.

=cut

sub register {
  my $self        = shift;
  my $invite_code = $ENV{CONVOS_INVITE_CODE};
  my ($output);

  if ($self->session('login')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    return $self->redirect_to('view');
  }

  $self->stash(form => 'register');

  if ($invite_code and $invite_code ne ($self->param('invite') || '')) {
    return $self->render('index', form => 'invite_only', status => 400);
  }
  if ($self->req->method ne 'POST') {
    return $self->render('index');
  }

  $self->delay(
    sub {
      my $delay = shift;
      $self->app->core->add_user($self->validation, $delay->begin);
    },
    sub {
      my ($delay, $validation, $user) = @_;
      return $self->render('index', status => 400) if $validation;
      $self->session(login => $user->{login});
      $self->redirect_to('wizard');
    }
  );
}

=head2 logout

Will delete data from session.

=cut

sub logout {
  my $self = shift;

  $self->delay(
    sub {
      my ($delay) = @_;
      return $delay->pass unless $self->session('kiosk');

      # TODO: Need to add delete_user() to clean up connection on logout
      # from kiosk mode account.
      # https://github.com/Nordaaker/convos/issues/104
      return $self->app->core->delete_user($self->session('login'), $delay->begin);
    },
    sub {
      my ($delay, $error) = @_;
      die $error if $error;
      $self->session(login => undef);
      $self->redirect_to('/');
    },
  );
}

=head2 edit

Change user profile.

=cut

sub edit {
  my $self   = shift;
  my $login  = $self->session('login');
  my $method = $self->req->method eq 'POST' ? '_edit' : 'render';

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->hgetall("user:$login", $delay->begin) if $method eq 'render';
      $self->conversation_list($delay->begin);
      $self->notification_list($delay->begin) if $self->stash('full_page');
    },
    sub {
      my ($delay, $user) = @_;
      $user = {} if ref $user ne 'HASH';
      $self->param($_ => $user->{$_}) for keys %$user;
      $self->$method;
    },
  );
}

=head2 tz_offset

Used to save timezone offset in hours. This value will be saved in session
under "tz_offset".

=cut

sub tz_offset {
  my $self = shift;
  my $offset = ($self->param('hour') || 0) - (localtime)[2];

  $self->session(tz_offset => $offset);
  $self->render(json => {offset => $offset});
}

sub _edit {
  my $self       = shift;
  my $login      = $self->session('login');
  my $validation = $self->validation;

  $validation->required('email')->like(qr{.\@.});
  $validation->optional('avatar')->size(3, 64);
  $validation->has_error and return $self->render(status => 400);
  $validation->output->{avatar} ||= '';

  $self->delay(
    sub {
      my $delay = shift;
      $self->redis->hmset("user:$login", $validation->output, $delay->begin);
    },
    sub {
      my ($delay, $saved) = @_;
      $self->render;
    },
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
