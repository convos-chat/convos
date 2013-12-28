package Convos::User;

=head1 NAME

Convos::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw/ as_id id_as /;
use Mojo::Asset::File;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use constant DEFAULT_URL => $ENV{DEFAULT_AVATAR_URL} || 'https://graph.facebook.com/%s/picture?height=40&width=40';
use constant GRAVATAR_URL => $ENV{GRAVATAR_AVATAR_URL} || 'https://gravatar.com/avatar/%s?s=40&d=retro';

has _avatar_ua => sub {
  my $self = shift;

  Mojo::UserAgent->new(
    connect_timeout => 1,
    inactivity_timeout => 5,
    max_redirects => 3,
    request_timeout => 5,
    server => $self->app->ua->server, # jhthorsen: not sure if this is just a bad hack, but it makes t/avatar.t happy
  );
};

=head1 METHODS

=head2 auth

Check authentication and login

=cut

sub auth {
  my $self = shift;

  if($self->session('login')) {
    return 1;
  }

  if($self->req->url->path =~ /\.json$/) {
    $self->render(json => {}, status => 403);
  }
  else {
    $self->redirect_to('/');
  }

  return 0;
}

=head2 avatar

Used to render an avatar for a user.

=cut

sub avatar {
  my $self = shift->render_later;
  my $id = $self->stash('id');
  my $user = $id =~ /^(\w+)/ ? $1 : 'd'; # d = not a real user, but a default user
  my $cache = $self->app->cache;
  my $cache_name;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hmget("user:$user", qw( avatar email ), $delay->begin);
    },
    sub {
      my($delay, $data) = @_;
      my $from_database = defined $data->[1] ? 1 : 0;
      my $url;

      $id = shift @$data || shift @$data || $id;

      if($id =~ /\@/) {
        $url = sprintf(GRAVATAR_URL, Mojo::Util::md5_sum($id));
      }
      elsif($from_database) {
        $url = sprintf(DEFAULT_URL, $id);
      }
      else {
        return $self->render(text => "Cannot find avatar.\n", status => 404);
      }

      $cache_name = $url;
      $cache_name =~ s![^\w]!_!g;
      $cache_name = "$cache_name.jpg";

      $cache->serve($self, $cache_name) and return $self->rendered;
      $self->app->log->debug("Getting avatar for $id: $url");
      $self->_avatar_ua->get($url, $delay->begin);
    },
    sub {
      my($delay, $tx) = @_;
      my $headers = $self->res->headers;

      if($tx->success) {
        open my $CACHE, '>', join('/', $cache->paths->[0], $cache_name) or die "Write avatar $cache_name: $!";
        syswrite $CACHE, $tx->res->body;
        close $CACHE or die "Close avatar $cache_name: $!";
        $cache->serve($self, $cache_name);
        $self->rendered;
      }
      else {
        $self->render(text => "Could not fetch avatar from third party.\n", status => 404);
      }
    },
  );
}

=head2 control

  /#host/control/start
  /#host/control/stop
  /#host/control/restart
  /#host/control/state

Used to control a connection. See L<Convos::Core/control>.

Special case is "state": It will return the state of the connection:
"disconnected", "error", "reconnecting" or "connected".

=cut

sub control {
  my $self = shift->render_later;
  my $command = $self->param('cmd') || 'state';

  if($command eq 'state') {
    $self->redis->hget(
      sprintf('user:%s:connection:%s', $self->session('login'), $self->stash('server')),
      'state',
      sub {
        my $redis = shift;
        my $state = shift || 'disconnected';

        $self->respond_to(
          json => { json => { state => $state } },
          any => { text => "$state\n" },
        );
      },
    );
  }
  elsif($self->req->method eq 'POST' and grep { $command eq $_ } qw( start stop restart )) {
    $self->app->core->control(
      $command,
      $self->session('login'),
      $self->stash('server'),
      sub {
        my($core, $sent) = @_;
        my $status = $sent ? 200 : 500;
        my $state = $command eq 'stop' ? 'stopping' : "${command}ing";

        $self->respond_to(
          json => { json => { state => $state }, status => $status },
          any => { text => "$state\n", status => $status },
        );
      },
    );
  }
  else {
    $self->respond_to(
      json => { json => {}, status => 400 },
      any => { text => "Invalid request\n", status => 400 },
    );
  }
}

=head2 login

Show the login form. Also responds to JSON requests with login status.

=cut

sub login {
  my $self = shift->render_later;

  unless($self->app->config->{redis_version}) {
    return $self->redis->info(server => sub {
      my $app = $self->app;
      $app->config->{redis_version} = $_[1] =~ /redis_version:(\d+\.\d+)/ ? $1 : '0e0';
      $app->log->info("Redis server version: @{[$app->config->{redis_version}]}");
      $self->login;
    });
  }

  $self->stash(form => 'login');

  if ($self->session('login')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    return $self->redirect_to('view');
  }
  if ($self->req->method ne 'POST') {
    return $self->respond_to(
      html => { template => 'index' },
      json => { json => { login => $self->session('login') || '' } },
    );
  }

  $self->app->core->login(
    $self->validation,
    sub {
      my ($core, $error) = @_;
      my $login;

      $error and return $self->render('index', status => 401);
      $login = $self->validation->param('login');
      $self->session(login => $login);
      $self->respond_to(
        html => sub { $self->redirect_last($login) },
        json => { json => { login => $login } },
      );
    },
  );
}

=head2 register

See L</login>.

=cut

sub register {
  my $self = shift->render_later;
  my $validation = $self->validation;
  my($code, $wanted_login);

  if ($self->session('login')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    return $self->redirect_to('view');
  }

  $self->stash(form => 'register');

  # cannt continue on error since the sismember(...$wanted_login...) will
  # fail without a login
  if($self->req->method ne 'POST') {
    return $self->render('index');
  }

  $code = $self->param('invite') || '';
  if ($self->app->config->{invite_code} && $code ne $self->app->config->{invite_code}) {
    return $self->render('index', form => 'invite_only', status => 400);
  }

  $validation->required('login')->like(qr/^\w+$/)->size(3, 15);
  $validation->required('email')->like(qr/.\@./);
  $validation->required('password_again')->equal_to('password');
  $validation->required('password')->size(5, 255);

  $wanted_login = $validation->param('login');

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->sismember('users', $wanted_login, $delay->begin);
      $self->redis->scard('users', $delay->begin);
    },
    sub {    # Check invitation unless first user
      my ($delay, $exists) = @_;

      $validation->error(login => ["taken"]) if $exists;
      return $self->render('index', status => 400) if $validation->has_error;

      $self->logf(debug => '[reg] New user login=%s', $wanted_login) if DEBUG;
      $self->session(login => $wanted_login);
      $self->app->core->start_convos_conversation($wanted_login);
      $self->redis->hmset(
        "user:$wanted_login" => {
          digest => $self->_digest($validation->output->{password}),
          email  => $validation->output->{email},
        },
        $delay->begin
      );
      $self->redis->sadd('users', $wanted_login, $delay->begin);
    },
    sub {
      my ($delay, @saved) = @_;
      $self->redirect_to('wizard');
    }
  );
}

sub _digest {
  crypt $_[1], join '', ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z')[rand 64, rand 64];
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
  my $self = shift->render_later;
  my $login = $self->session('login');
  my $method = $self->req->method eq 'POST' ? '_edit' : 'render';
  my $partial = $self->req->is_xhr;

  $self->stash(body_class => 'convos with-sidebar');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hgetall("user:$login", $delay->begin) if $method eq 'render';
      $self->connection_list($delay->begin);
      $self->conversation_list($delay->begin) unless $partial;
      $self->notification_list($delay->begin) unless $partial;
      $delay->begin->();
    },
    sub {
      my($delay, $user) = @_;
      $user = {} if ref $user ne 'HASH';
      $self->param($_ => $user->{$_}) for keys %$user;
      $self->$method;
    },
  );
}

sub _edit {
  my $self = shift;
  my $login = $self->session('login');
  my $validation = $self->validation;

  $validation->required('email')->like(qr{.\@.});
  $validation->optional('avatar')->size(3, 64);
  $validation->has_error and return $self->render;
  $validation->output->{avatar} ||= '';

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hmset("user:$login", $validation->output, $delay->begin);
    },
    sub {
      my ($delay, $saved) = @_;
      $self->render;
    }
  );
}

=head2 edit_connection

Change a connection.

=cut

sub edit_connection {
  my $self = shift->render_later;
  my $validation = $self->validation;

  $validation->input->{channels} = [$self->param('channels')];
  $validation->input->{login} = $self->session('login');
  $validation->input->{lookup} = $self->stash('server');
  $validation->input->{server} = $self->req->body_params->param('server');
  $validation->input->{tls} ||= 0;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->update_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $errors, $changed) = @_;
      return $self->settings if $errors;
      return $self->redirect_to('settings');
    }
  );
}

=head2 delete_connection

Delete a connection.

=cut

sub delete_connection {
  my $self = shift->render_later;
  my $validation = $self->validation;

  $validation->input->{login} = $self->session('login');
  $validation->input->{server} = $self->stash('server');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->delete_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $error) = @_;
      return $self->render_not_found if $error;
      return $self->redirect_to('settings');
    }
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
