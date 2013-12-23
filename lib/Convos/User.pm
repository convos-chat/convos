package Convos::User;

=head1 NAME

Convos::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Convos::Client';
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
  return 1 if $self->session('login');
  $self->redirect_to('/');
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
  if($self->req->method ne 'POST' or !$self->param('login')) {
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

=head2 settings

Used to retrieve connection information.

=cut

sub settings {
  my $self        = shift->render_later;
  my $hostname    = Convos::Core::Util::hostname();
  my $login       = $self->session('login');
  my $server      = $self->stash('server') || 0;
  my $with_layout = $self->req->is_xhr ? 0 : 1;
  my @conversation;

  $self->stash(
    server       => $server,
    body_class   => 'settings',
    conversation => \@conversation,
    nick         => $login,
    target       => 'settings',
  );

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->smembers("user:$login:connections", $_[0]->begin);
    },
    sub {
      my ($delay, $hosts) = @_;
      my $cb = $delay->begin;

      unless(@$hosts) {
        $self->redirect_to('wizard');
        return;
      }

      $self->redis->execute(
        [zrange => "user:$login:conversations", 0, -1],
        (map { [hgetall => "user:$login:connection:$_"] } @$hosts),
        $cb
      );
    },
    sub {
      my ($delay, $conversations, @connections) = @_;
      my $cobj = Convos::Core::Connection->new(login => $login, server => 'anything');

      $self->logf(debug => '[settings] connection data %s', \@connections) if DEBUG;

      for my $conn (@connections) {
        $cobj->server($conn->{server} || $conn->{host});    # back compat
        $conn->{event}    = 'connection';
        $conn->{lookup}   = $conn->{server} || $conn->{host};
        $conn->{channels} = [$cobj->channels_from_conversations($conversations)];
        $conn->{server} ||= $conn->{host};                  # back compat
        $conn->{password} ||= '';
        push @conversation, $conn;
      }

      $self->redis->hgetall("user:$login", $delay->begin);
      $self->redis->get("avatar:$login\@$hostname", $delay->begin);

      push @conversation, $self->app->config('default_connection');
      $conversation[-1]{event}  = 'connection';
      $conversation[-1]{lookup} = '';
      $delay->begin->();
    },
    sub {
      my ($delay, $user, $avatar) = @_;

      if ($with_layout) {
        $self->conversation_list($delay->begin);
        $self->notification_list($delay->begin);
      }

      if ($user) {
        unshift @conversation, {
          event => 'user',
          avatar => $avatar,
          email => $user->{email},
          hostname => $hostname,
          login => $login,
        };
      }

      $delay->begin->();
    },
    sub {
      my ($delay, @res) = @_;

      return $self->render('client/view') if $with_layout;
      return $self->render('client/conversation', layout => undef);
    },
  );
}

=head2 add_connection

Add a new connection.

=cut

sub add_connection {
  my $self  = shift->render_later;
  my $validation = $self->validation;

  $validation->input->{channels} = [$self->param('channels')];
  $validation->input->{login} = $self->session('login');
  $validation->input->{tls} ||= 0;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->add_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $errors, $conn) = @_;

      if($errors and $self->param('wizard')) {
        $self->render('user/wizard', body_class => 'tactile');
      }
      elsif($errors) {
        $self->settings;
      }
      else {
        $self->redirect_to($self->param('wizard') ? 'convos' : 'settings');
      }
    },
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

=head2 edit_user

Change user profile.

=cut

sub edit_user {
  my $self       = shift->render_later;
  my $login      = $self->session('login');
  my $hostname   = Convos::Core::Util::hostname();
  my $validation = $self->validation;

  $validation->required('email')->like(qr{.\@.});
  $validation->optional('avatar')->size(1, 64);

  if($validation->has_error) {
    return $self->render;
  }

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hmset("user:$login", $validation->output, $delay->begin);
      $delay->begin->();
    },
    sub {
      my ($delay, @saved) = @_;
      return $self->render(json => {}) if $self->req->is_xhr;
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
