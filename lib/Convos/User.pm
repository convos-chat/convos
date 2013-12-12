package Convos::User;

=head1 NAME

Convos::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Convos::Client';
use Convos::Core::Util qw/ as_id id_as /;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;

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

=head2 login

Show the login form. Also responds to JSON requests with login status.

=cut

sub login {
  my $self = shift->render_later;
  my %credentials;

  $self->stash(form => 'login');

  if ($self->session('login')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    return $self->redirect_to('view');
  }
  if ($self->req->method eq 'POST') {
    $credentials{$_} = $self->param($_) for qw( login password );
  }
  if (2 != grep { $_ } values %credentials) {
    return $self->respond_to(
      html => { template => 'index' },
      json => { json => { login => $self->session('login') || '' } },
    );
  }

  $self->app->core->login(
    \%credentials,
    sub {
      my ($core, $error) = @_;

      if ($error) {
        return $self->render('index', message => 'Invalid username/password.', status => 401);
      }

      $self->session(login => $credentials{login});
      $self->respond_to(
        html => sub { $self->redirect_last($credentials{login}); },
        json => { json => { login => $self->session('login') || '' } },
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
      $self->redis->hmset(
        "user:$wanted_login",
        digest => $self->_digest($self->param('password')),
        email  => scalar $self->param('email'),
        $delay->begin
      );
      $self->redis->sadd('users', $wanted_login, $delay->begin);
    },
    sub {
      my ($delay, @saved) = @_;
      $self->redirect_to('settings');
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

      return $self->$cb() unless @$hosts;
      return $self->redis->execute([zrange => "user:$login:conversations", 0, -1],
        (map { [hgetall => "user:$login:connection:$_"] } @$hosts), $cb,);
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
        push @conversation, $conn;
      }

      if (@conversation) {
        $self->redis->hgetall("user:$login", $delay->begin);
        $self->redis->get("avatar:$login\@$hostname", $delay->begin);
      }
      else {
        push @conversation, {event => 'welcome'};
      }

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
        unshift @conversation,
          {event => 'user', avatar => $avatar, email => $user->{email}, login => $login, hostname => $hostname,};
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
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->add_connection(
        {
          channels => [$self->param('channels')],
          login    => $self->session('login'),
          nick     => $self->param('nick') || '',
          server   => $self->param('server') || '',
          tls      => $self->param('tls') || 0,
          user     => $login,
        },
        $delay->begin,
      );
    },
    sub {
      my ($delay, $errors, $conn) = @_;
      $self->stash(errors => $errors) if $errors;
      return $self->settings if $errors;
      return $self->redirect_to('settings');
    },
  );
}

=head2 edit_connection

Change a connection.

=cut

sub edit_connection {
  my $self = shift->render_later;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->update_connection(
        {
          channels => [$self->param('channels')],
          login    => $self->session('login'),
          lookup   => $self->stash('server') || '',
          nick     => $self->param('nick') || '',
          server   => $self->req->body_params->param('server') || '',
          tls      => $self->param('tls') || 0,
          user     => $self->session('login'),
        },
        $delay->begin,
      );
    },
    sub {
      my ($delay, $errors, $changed) = @_;
      $self->stash(errors => $errors) if $errors;
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

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->delete_connection({login => $self->session('login'), server => $self->stash('server'),},
        $delay->begin,);
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
  my $self     = shift->render_later;
  my $login    = $self->session('login');
  my $hostname = Convos::Core::Util::hostname();
  my $avatar   = $self->param('avatar');
  my %settings;

  $settings{email} = $self->param('email') if defined $self->param('email');

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hmset("user:$login", %settings, $delay->begin);
      $self->redis->set("avatar:$login\@$hostname", $avatar, $delay->begin) if defined $avatar;
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
