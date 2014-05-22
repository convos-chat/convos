package Convos;

=head1 NAME

Convos - Multiuser IRC proxy with web interface

=head1 VERSION

0.5

=head1 DESCRIPTION

Convos is to a multi-user IRC Proxy, that also provides a easy to use Web
interface. Feature list:

=over 4

=item * Always online

The backend server will keep you logged in and logs all the activity
in your archive.

=item * Archive

All chats will be logged and indexed, which allow you to search in
earlier conversations.

=item * Avatars

The chat contains profile pictures which can be retrieved from Facebook
or from gravatar.com.

=item * Include external resources

Links to images and video will be displayed inline. No need to click on
the link to view the data.

=back

=head2 Architecture principles

=over 4

=item * Keep the JS simple and manageable

=item * Use Redis to manage state / publish subscribe

=item * Archive logs in plain text format, use ack to search them.

=item * Bootstrap-based user interface

=back

=head1 RUNNING CONVOS

Convos has sane defaults so after installing L<Convos> you should be
able to just run it:

  # Install
  $ cpanm Convos
  # Run it
  $ convos backend &
  $ convos daemon

The above works, but if you have a lot of users you probably want to use
L<hypnotoad|Mojo::Server::Hypnotoad> instead of C<daemon>:

  $ hypnotoad $(which convos)

The command above will start a full featured, UNIX optimized, preforking
non-blocking webserver. Run the same command again, and the webserver
will L<hot reload|Mojo::Server::Hypnotoad/USR2> the source code without
loosing any connections.

=head2 Configuration

You can also customize the config by setting C<MOJO_CONFIG> before
running any of the commands above. Example:

  $ MOJO_CONFIG=$HOME/.convos.conf convos daemon

You can use L<https://github.com/Nordaaker/convos/blob/release/convos.conf>
as config file template.

=head2 Environment

Convos can be configured with the following environment variables:

=over 4

=item * CONVOS_BACKEND_EMBEDDED=1

Set CONVOS_MANUAL_BACKEND to a true value if you want to force the frontend
to start the backend embedded. This is useful if you want to test L<Convos>
with L<morbo|Mojo::Server::Morbo>.

=item * CONVOS_DEBUG=1

Set CONVOS_DEBUG for extra debug output to STDERR.

=item * CONVOS_MANUAL_BACKEND=1

Disable the frontend from automatically starting the backend.

=item * CONVOS_PING_INTERVAL=30

Set how often to send "keep-alive" through the web socket. Default is
every 30 second.

=item * CONVOS_REDIS_URL

This is the URL to the Redis backend, and should follow this format:

  redis://x:password@server:port/database_index
  redis://127.0.0.1:6379/1 # suggested value

Convos will use C<REDISTOGO_URL> or C<DOTCLOUD_DATA_REDIS_URL> if
C<CONVOS_REDIS_URL> is not set.

It is also possible to set C<CONVOS_REDIS_INDEX=2> to use the
database index 2, instead of the default. This is useful when
C<REDISTOGO_URL> or C<DOTCLOUD_DATA_REDIS_URL> does not contain
the datbase index.

=item * CONVOS_INVITE_CODE

If set must be appended to register url. Example:

  http://your.convos.by/register/some-secret-invite-code

=item * MOJO_IRC_DEBUG=1

Set MOJO_IRC_DEBUG for extra IRC debug output to STDERR.

=back

=head2 HTTP headers

=over 4

=item * X-Request-Base

Set this header if you are mounting Convos under a custom path. Example
with nginx:

  # mount the application under /convos
  location /convos {
    # remove "/convos" from the forwarded request
    rewrite ^/convos(.*)$ $1 break;

    # generic headers for correct handling of ws and http
    proxy_http_version 1.1;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $host;

    # set this if you are running SSL
    proxy_set_header X-Forwarded-HTTPS 1;

    # inform Convos the full location where it is mounted
    proxy_set_header X-Request-Base "https://some-domain.com/convos";

    # tell nginx where Convos is running
    proxy_pass http://10.0.0.10:8080;
  }

=back

=head1 RESOURCES

=over 4

=item * Homepage: L<http://convos.by>

=item * Project page: L<https://github.com/Nordaaker/convos>

=item * Icon: L<https://raw.github.com/Nordaaker/convos/master/public/image/icon.svg>

=item * Logo: L<https://raw.github.com/Nordaaker/convos/master/public/image/logo.svg>

=back

=head1 SEE ALSO

=over 4

=item * L<Convos::Archive>

Mojolicious controller for IRC logs.

=item * L<Convos::Client>

Mojolicious controller for IRC chat.

=item * L<Convos::User>

Mojolicious controller for user data.

=item * L<Convos::Core>

Backend functionality.

=back

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Redis;
use Mojo::Util qw( md5_sum );
use File::Spec::Functions qw( catdir catfile tmpdir );
use File::Basename qw( dirname );
use Convos::Core;
use Convos::Core::Util ();
use Convos::Upgrader;

our $VERSION = '0.5';

=head1 ATTRIBUTES

=head2 archive

Holds a L<Convos::Core::Archive> object.

=head2 cache

Holds a L<Mojolicious::Static> object pointing to a cache dir.
The directory is "/tmp/convos" by default.

=head2 core

Holds a L<Convos::Core> object.

=head2 upgrader

Holds a L<Convos::Upgrader> object.

=cut

has archive => sub {
  my $self = shift;
  Convos::Core::Archive->new($self->config->{archive} || $self->path_to('archive'));
};

has cache => sub {
  my $self = shift;
  my $dir = $self->config->{cache_dir} ||= catfile(tmpdir, 'convos');

  $self->log->info("Cache dir: $dir");
  mkdir $dir or die "mkdir $dir: $!" unless -d $dir;

  Mojolicious::Static->new(paths => [$dir]);
};

has core => sub {
  my $self = shift;
  my $core = Convos::Core->new;

  $core->log($self->log);
  $core->redis->server($self->redis->server);
  $core;
};

has upgrader => sub {
  Convos::Upgrader->new(redis => shift->redis);
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;
  my $config;

  $self->{convos_executable_path} = $0;    # required to work from within toadfarm
  $self->_from_cpan;
  $config = $self->plugin('Config');

  if (my $log = $config->{log}) {
    $self->log->level($log->{level}) if $log->{level};
    $self->log->path($log->{file}) if $log->{file} ||= $log->{path};
    delete $self->log->{handle};           # make sure it's fresh to file
  }

  $self->cache;                            # make sure cache is ok
  $self->plugin('Convos::Plugin::Helpers');
  $self->secrets([time]);                  # will be replaced by _set_secrets()
  $self->sessions->default_expiration(86400 * 30);
  $self->_assets($config);
  $self->_public_routes;
  $self->_private_routes;

  if (!eval { Convos::Plugin::Helpers::REDIS_URL() } and $config->{redis}) {
    $self->log->warn("redis url from config file will be deprecated. Run 'perldoc Convos' for alternative setup.");
    $ENV{CONVOS_REDIS_URL} = $config->{redis};
  }
  if (!$ENV{CONVOS_REDIS_URL} and $self->mode eq 'production') {
    $ENV{CONVOS_REDIS_URL} = 'redis://127.0.0.1:6379/1';
    $self->log->info("Using default CONVOS_REDIS_URL=$ENV{CONVOS_REDIS_URL}");
  }

  if (!$ENV{CONVOS_INVITE_CODE} and $config->{invite_code}) {
    $self->log->warn(
      "invite_code from config file will be deprecated. Set the CONVOS_INVITE_CODE env variable instead.");
    $ENV{CONVOS_INVITE_CODE} = $config->{invite_code};
  }

  $self->defaults(full_page => 1);
  $self->hook(
    before_dispatch => sub {
      my $c = shift;

      $c->stash(full_page => !($c->req->is_xhr || $c->param('_pjax')));

      if (my $base = $c->req->headers->header('X-Request-Base')) {
        $c->req->url->base(Mojo::URL->new($base));
      }
    }
  );

  Mojo::IOLoop->timer(5 => sub { $ENV{CONVOS_MANUAL_BACKEND}     or $self->_start_backend; });
  Mojo::IOLoop->timer(0 => sub { $ENV{CONVOS_SKIP_VERSION_CHECK} or $self->_check_version; });
  Mojo::IOLoop->timer(0 => sub { $self->_set_secrets });
}

sub _assets {
  my ($self, $config) = @_;

  $self->plugin('AssetPack' => {rebuild => $config->{AssetPack}{rebuild} // 1});
  $self->asset('convos.css', '/sass/main.scss');
  $self->asset(
    'convos.js',              '/js/jquery.min.js',     '/js/jquery.hotkeys.js', '/js/jquery.fastbutton.js',
    '/js/jquery.pjax.js',     '/js/selectize.js',      '/js/globals.js',        '/js/jquery.doubletap.js',
    '/js/ws-reconnecting.js', '/js/jquery.helpers.js', '/js/convos.chat.js',
  );
}

sub _check_version {
  my $self = shift;
  my $log  = $self->log;

  $self->upgrader->running_latest(
    sub {
      my ($upgrader, $latest) = @_;
      $latest and return;
      $log->error(
        "The database schema has changed.\nIt must be updated before we can start!\n\nRun '$self->{convos_executable_path} upgrade', then try again.\n\n"
      );
      exit;
    },
  );
}

sub _from_cpan {
  my $self   = shift;
  my $home   = catdir dirname(__FILE__), 'Convos';
  my $config = catfile $home, 'convos.conf';

  -r $config or return;
  $self->home->parse($home);
  $self->static->paths->[0]   = $self->home->rel_dir('public');
  $self->renderer->paths->[0] = $self->home->rel_dir('templates');
}

sub _private_routes {
  my $self = shift;
  my $r = $self->routes->route->bridge('/')->to('user#auth', layout => 'view');
  my $network_r;

  $self->plugin('LinkEmbedder');

  $r->websocket('/socket')->to('chat#socket')->name('socket');
  $r->get('/chat/command-history')->to('client#command_history');
  $r->get('/chat/conversations')->to(cb => sub { shift->conversation_list }, layout => undef)
    ->name('conversation.list');
  $r->get('/chat/notifications')->to(cb => sub { shift->notification_list }, layout => undef)
    ->name('notification.list');
  $r->post('/chat/notifications/clear')->to('client#clear_notifications', layout => undef)->name('notifications.clear');
  $r->any('/connection/add')->to('connection#add_connection')->name('connection.add');
  $r->any('/connection/:name/control')->to('connection#control')->name('connection.control');
  $r->any('/connection/:name/edit')->to('connection#edit_connection')->name('connection.edit');
  $r->get('/connection/:name/delete')->to(template => 'connection/delete_connection', layout => 'tactile');
  $r->post('/connection/:name/delete')->to('connection#delete_connection')->name('connection.delete');
  $r->any('/network/add')->to('connection#add_network')->name('network.add');
  $r->any('/network/:name/edit')->to('connection#edit_network')->name('network.edit');
  $r->get('/oembed')->to('oembed#generate', layout => undef)->name('oembed');
  $r->any('/profile')->to('user#edit')->name('user.edit');
  $r->post('/profile/timezone/offset')->to('user#tz_offset');
  $r->get('/wizard')->to('connection#wizard')->name('wizard');

  $network_r = $r->route('/:network');
  $network_r->get('/*target')->to('client#conversation')->name('view');
  $network_r->get('/')->to('client#conversation')->name('view.network');
}

sub _public_routes {
  my $self = shift;
  my $r = $self->routes->route->to(layout => 'tactile');

  $r->get('/')->to('client#route')->name('index');
  $r->get('/avatar')->to('user#avatar')->name('avatar');
  $r->get('/login')->to('user#login')->name('login');
  $r->post('/login')->to('user#login');
  $r->get('/register/:invite', {invite => ''})->to('user#register')->name('register');
  $r->post('/register/:invite', {invite => ''})->to('user#register');
  $r->get('/logout')->to('user#logout')->name('logout');
  $r;
}

sub _set_secrets {
  my $self  = shift;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->lrange('convos:secrets', 0, -1, $delay->begin);
      $redis->getset('convos:secrets:lock' => 1, $delay->begin);
      $redis->expire('convos:secrets:lock' => 5);
    },
    sub {
      my ($delay, $secrets, $locked) = @_;

      $secrets ||= $self->config->{secrets};

      return $self->app->secrets($secrets) if $secrets and @$secrets;
      return $self->_set_secrets if $locked;
      $secrets = [md5_sum rand . $$ . time];
      $self->app->secrets($secrets);
      $redis->lpush('convos:secrets', $secrets->[0]);
      $redis->del('convos:secrets:lock');
    },
  );
}

sub _start_backend {
  my $self  = shift;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->getset('convos:backend:lock' => 1, $delay->begin);
      $redis->get('convos:backend:pid', $delay->begin);
      $redis->expire('convos:backend:lock' => 5);
    },
    sub {
      my ($delay, $locked, $pid) = @_;

      if ($pid and kill 0, $pid) {
        $self->log->debug("Backend $pid is running.");
      }
      elsif ($locked) {
        $self->log->debug('Another process is starting the backend.');
      }
      elsif ($SIG{USR2}) {    # hypnotoad
        $self->_start_backend_as_external_app;
      }
      elsif ($ENV{CONVOS_BACKEND_EMBEDDED} or !$SIG{QUIT}) {    # forced or ./script/convos daemon
        $self->log->debug('Starting embedded backend.');
        $redis->set('convos:backend:pid' => $$);
        $redis->del('convos:backend:lock');
        $self->core->start;
      }
      else {                                                    # morbo
        $self->log->warn(
          'Set CONVOS_BACKEND_EMBEDDED=1 to automatically start the backend from morbo. (The backend is not running)');
        $redis->del('convos:backend:lock');
      }
    },
  );
}

sub _start_backend_as_external_app {
  my $self = shift;

  local $0 = $self->{convos_executable_path};

  if (!-x $0) {
    $self->log->error("Cannot execute $0: Not executable");
    return;
  }

  if (my $pid = fork) {
    $self->log->debug("Starting $0 backend with double fork");
    wait;    # wait for "fork and exit" below
    $self->log->info("Detached $0 backend ($pid=$?)");
    return $pid;    # parent process returns
  }
  elsif (!defined $pid) {
    $self->log->error("Can't start external backend, fork failed: $!");
    return;
  }

  # start detaching new process from hypnotoad
  if (!POSIX::setsid) {
    $self->log->error("Can't start a new session for backend: $!");
    exit $!;
  }

  # detach child from hypnotoad or die trying
  defined(fork and exit) or die;

  # replace fork with "convos backend" process
  delete $ENV{MOJO_CONFIG} if $ENV{TOADFARM_APPLICATION_CLASS};
  $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  $self->log->debug("Replacing current process with $0 backend");
  { exec $0 => 'backend' }
  $self->log->error("Failed to replace current process: $!");
  exit;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
