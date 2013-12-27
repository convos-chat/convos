package Convos::User;

=head1 NAME

Convos::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Convos::Client';
use Convos::Core::Util qw( as_id id_as $URL_RE );
use Mojo::Asset::File;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use constant DEFAULT_URL => $ENV{DEFAULT_AVATAR_URL} || 'https://graph.facebook.com/%s/picture?height=40&width=40';
use constant GRAVATAR_URL => $ENV{GRAVATAR_AVATAR_URL} || 'https://gravatar.com/avatar/%s?s=40&d=retro';

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

=head2 avatar_from_database

This is a public resource which will respond with avatar for a user from the
local database. Will respond with 404 if the user could not be found.

=cut

sub avatar_from_database {
  my $self = shift->render_later;
  my $login = shift || $self->stash('login');
  my $cb = shift || '_avatar_failed';

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->_avatar_from_cache("loopback-$login.jpg", $delay->begin);
    },
    sub { # avatar is not cached
      my($delay) = @_;
      $self->redis->hmget("user:$login", qw( avatar email ), $delay->begin);
    },
    sub {
      my($delay, $data) = @_;
      my $lookup = $data->[0] || $data->[1];

      return $delay->begin(0)->(0) unless $lookup;
      return $self->_avatar_from_3rd_party($lookup, "loopback-$login.jpg", $delay->begin);
    },
    sub {
      my($delay, $avatar_from_3rd_party) = @_;
      $self->$cb("Could not find avatar.\n") unless $avatar_from_3rd_party;
    }
  );
}

=head2 avatar_from_irc

This resource require you to be logged in. It will run "/whois" on the
requested nick and use the response to lookup avatar:

=over 4

=item 1. L</avatar_from_database>

First step is to look up the "user" response from the "/whois" in the
local database.

=item 2. Third party lookup

=item 3. Fallback

The fallback is to serve a generated avatar from L<http://gravatar.com>.

=back

=cut

sub avatar_from_irc {
  my $self = shift->render_later;
  my $login = $self->session('login');
  my $nick = $self->stash('nick');
  my $server = $self->stash('server');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->_avatar_from_cache("$server-$nick.jpg", $delay->begin);
    },
    sub { # avatar is not cached
      my($delay) = @_;
      $self->app->core->control(write => $login, $server => "WHOIS $nick", $delay->begin);
    },
    sub {
      my($delay, $whois) = @_;
      return $self->_avatar_failed("No such nick.\n") unless $whois and $whois->{user};
      $delay->begin(0)->($whois);
      $self->avatar_from_database($whois->{user}, $delay->begin);
    },
    sub {
      my($delay, $whois, $not_found_in_database) = @_; # not local user

      $delay->begin(0)->($whois);

      if($whois->{realname} =~ /($URL_RE)/) {
        my $url = $1;
        $url =~ s!/profile$!/avatar.jpg!;
        $self->_avatar_from_3rd_party($url, "$server-$nick.jpg", $delay->begin);
      }
    },
    sub {
      my($delay, $whois, $avatar_from_alien_convos) = @_;

      return if $avatar_from_alien_convos;
      return $self->_avatar_from_3rd_party("$whois->{user}\@$server", "$server-$nick.jpg", $delay->begin);
    },
    sub {
      my($delay, $avatar_from_3rd_party) = @_;
      $self->_avatar_failed("3rd party failed.\n") unless $avatar_from_3rd_party;
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

sub _connection_name {
  my $self = shift;

  $self->url_for('profile', login => $self->session('login'))->to_abs->to_string;
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
        $conn->{tls} ||= 0;
        push @conversation, $conn;
      }

      $self->redis->hgetall("user:$login", $delay->begin);

      push @conversation, $self->app->config('default_connection');
      $conversation[-1]{event}  = 'connection';
      $conversation[-1]{lookup} = '';
      $conversation[-1]{tls} ||= 0;
      $delay->begin->();
    },
    sub {
      my ($delay, $user) = @_;

      if ($with_layout) {
        $self->conversation_list($delay->begin);
        $self->notification_list($delay->begin);
      }

      if ($user) {
        unshift @conversation, {
          event => 'user',
          avatar => $user->{avatar} || '',
          email => $user->{email},
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
  $validation->input->{name} = $self->_connection_name;
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
  $validation->input->{name} = $self->_connection_name;
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

sub _avatar_failed {
  my($self, $message) = @_;
  my $format = $self->stash('format') || 'html';
  my $res = $self->res;

  $self->app->log->warn($message);
  $res->code(404);
  $res->headers->content_type('image/jpeg');
  $res->content->asset($self->app->static->file('/image/avatar/404.jpg'));
  $self->rendered;
}

sub _avatar_from_cache {
  my($self, $filename, $cb) = @_;
  my $app = $self->app;
  my $nick = $filename =~ /-(.*\.jpg)/ ? $1 : '';

  # TODO: Add timeout for cached avatars?
  return $self->rendered if $nick and $app->static->serve($self, "/image/avatar/$nick");
  return $self->rendered if $app->cache->serve($self, $filename);
  return $self->$cb;
}

sub _avatar_from_3rd_party {
  my($self, $lookup, $filename, $cb) = @_;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      my $url;

      if($lookup =~ /^http/) {
        $url = $lookup;
      }
      elsif($lookup =~ /\@/) {
        $url = sprintf(GRAVATAR_URL, Mojo::Util::md5_sum($lookup));
      }
      else {
        $url = sprintf(DEFAULT_URL, $lookup);
      }

      $self->app->log->debug("Getting avatar for $lookup: $url");
      $self->app->ua->get($url, $delay->begin);
    },
    sub {
      my($delay, $tx) = @_;
      my $headers = $self->res->headers;
      my $cache = $self->app->cache;

      unless($tx->success) {
        return $self->$cb(0);
      }

      open my $CACHE, '>', join('/', $cache->paths->[0], $filename) or die "Write avatar $filename $!";
      syswrite $CACHE, $tx->res->body;
      close $CACHE or die "Close avatar $filename $!";
      $cache->serve($self, $filename);
      $self->rendered;
      $self->$cb(1);
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
