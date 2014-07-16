package Convos::User;

=head1 NAME

Convos::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw/ as_id id_as /;
use Mojo::Asset::File;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use constant DEFAULT_URL  => $ENV{DEFAULT_AVATAR_URL}  || 'https://graph.facebook.com/%s/picture?height=40&width=40';
use constant GRAVATAR_URL => $ENV{GRAVATAR_AVATAR_URL} || 'https://gravatar.com/avatar/%s?s=40&d=retro';

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

=head2 avatar

Used to render an avatar for a user.

=cut

sub avatar {
  my $self = shift;
  my $host = $self->param('host');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->hget('convos:host2convos', $host, $delay->begin);
    },
    sub {
      my ($delay, $convos_url) = @_;

      return $self->_avatar_discover if !$convos_url;
      return $self->_avatar_local if $convos_url eq 'loopback';
      return $self->_avatar_remote($convos_url);
    },
  );
}

sub _avatar_cache_and_serve {
  my ($self, $cache_name, $tx) = @_;
  my $cache = $self->app->cache;

  if (!$tx->res->code or $tx->res->code ne '200') {
    return $self->_avatar_error(404);
  }

  open my $CACHE, '>', join('/', $cache->paths->[0], $cache_name)
    or return $self->_avatar_error(500, "Write avatar $cache_name: $!");
  syswrite $CACHE, $tx->res->body;
  close $CACHE or return $self->_avatar_error(500, "Close avatar $cache_name: $!");
  $cache->serve($self, $cache_name);
  $self->rendered;
}

sub _avatar_discover {
  my ($self, $cb) = @_;
  my $host = $self->param('host');
  my $user = $self->param('user');

  unless ($self->session('login')) {
    return $self->_avatar_error(500, 'Cannot discover avatar unless logged in');
  }

  # TODO: Need to do a WHOIS to see if the user has convos_url set
  my $url = sprintf(GRAVATAR_URL, Mojo::Util::md5_sum("$user\@$host"));
  $self->redirect_to($url);
}

sub _avatar_error {
  my ($self, $code, $message) = @_;

  $self->render_static("/image/avatar-$code.gif");
  $self->app->log->error($message) if $message;
}

sub _avatar_local {
  my $self = shift;
  my $host = $self->param('host');
  my $user = $self->param('user');
  my $cache_name;

  $user =~ s!^~!!;    # somenick!~someuser@1.2.3.4

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->hmget("user:$user", qw( avatar email ), $delay->begin);
    },
    sub {
      my ($delay, $data) = @_;
      my $id = shift @$data || shift @$data || "$user\@$host";
      my $url;

      if ($id =~ /\@/) {
        $url = sprintf(GRAVATAR_URL, Mojo::Util::md5_sum($id));
      }
      else {
        $url = sprintf(DEFAULT_URL, $id);
      }

      $cache_name = $url;
      $cache_name =~ s![^\w]!_!g;
      $cache_name = "$cache_name.jpg";

      return $self->rendered if $self->app->cache->serve($self, $cache_name);
      $self->app->log->debug("Getting avatar for $id: $url");
      $self->app->ua->get($url => $delay->begin);    # get from either from facebook or gravatar
    },
    sub {
      $self->_avatar_cache_and_serve($cache_name, $_[1]);
    },
  );
}


sub _avatar_remote {
  my $self = shift;
  my $url  = Mojo::URL->new(shift);                  # Example $url = http://wirc.pl/
  my $cache_name;

  unless ($self->session('login')) {
    return $self->_avatar_error(500, 'Cannot discover avatar unless logged in');
  }

  $self->delay(
    sub {
      my ($delay) = @_;

      $url->path('/avatar');
      $url->query(map { $_ => scalar $self->param($_) } qw( host user ));

      $cache_name = $url;
      $cache_name =~ s![^\w]!_!g;
      $cache_name = "$cache_name.jpg";

      return $self->rendered if $self->app->cache->serve($self, $cache_name);
      $self->app->log->debug("Getting remote avatar from $url");
      $self->app->ua->get($url => $delay->begin);    # get from either from facebook or gravatar
    },
    sub {
      $self->_avatar_cache_and_serve($cache_name, $_[1]);
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
          {digest => $self->_digest($output->{password}), email => $output->{email}, avatar => $output->{email},},
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
