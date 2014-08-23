package Convos::Controller::User;

=head1 NAME

Convos::Controller::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw/ as_id id_as /;
use Mojo::Asset::File;
use Mojo::Date;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;

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
  my $validation  = $self->validation;
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

  $validation->required('login')->like(qr/^\w+$/)->size(3, 15);
  $validation->required('email')->like(qr/.\@./);
  $validation->required('password_again')->equal_to('password');
  $validation->required('password')->size(5, 255);
  $output = $validation->output;

  $self->delay(
    sub {
      my $delay = shift;
      $self->redis->sismember('users', $output->{login}, $delay->begin);
      $self->redis->scard('users', $delay->begin);
    },
    sub {    # Check invitation unless first user
      my ($delay, $exists) = @_;

      $validation->error(login => ['taken']) if $exists;
      return $self->render('index', status => 400) if $validation->has_error;

      $self->logf(debug => '[reg] New user login=%s', $output->{login}) if DEBUG;
      $self->session(login => $output->{login});
      $self->app->core->start_convos_conversation($output->{login});
      $self->redis->hmset(
        "user:$output->{login}" =>
          {digest => $self->_digest($output->{password}), email => $output->{email}, avatar => $output->{email}},
        $delay->begin
      );
      $self->redis->sadd(users => $output->{login}, $delay->begin);
    },
    sub {
      my ($delay, @saved) = @_;
      $self->redirect_to('wizard');
    }
  );
}

=head2 logout

Will delete data from session.

=cut

sub logout {
  my $self = shift;
  $self->session(login => undef);
  $self->redirect_to('/');
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

sub _digest {
  crypt $_[1], join '', ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z')[rand 64, rand 64];
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
