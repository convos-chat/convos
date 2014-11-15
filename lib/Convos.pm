package Convos;

=head1 NAME

Convos - Multiuser IRC proxy with web interface

=head1 VERSION

0.8602

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

=item * Bootstrap-based user interface

=back

=head1 RUNNING CONVOS

Convos has sane defaults so after installing L<Convos> you should be
able to just run it:

  # Install
  $ cpanm Convos
  # Run it
  $ convos daemon --listen http://*:8080

The steps above will install and run Convos in a single process. This is a
very quick way to get started, but we incourage to run Convos as one backend
and one frontend:

  # Start the backend first
  $ convos backend start

  # Then start the frontend
  $ convos daemon --listen http://*:8080

This allow you to upgrade and restart the frontend, without having to
reconnect to the IRC servers.

See L<Convos::Manual::Running> for more details.

=head1 CUSTOM TEMPLATES

Some parts of the Convos templates can include custom content. Example:

  # Create a directory where you can store the templates
  $ mkdir -p custom-convos/vendor

  # Edit the template you want to customize
  $ $EDITOR custom-convos/vendor/login_footer.html.ep

  # Start convos with CONVOS_TEMPLATES set. Without /vendor at the end
  $ CONVOS_TEMPLATES=$PWD/custom-convos convos daemon --listen http://*:5000

Any changes to the templates require the server to restart.

The templates that can be customized are:

=over 4

=item * vendor/login_footer.html.ep

This template will be included below the form on the C</login> page.

=item * vendor/register_footer.html.ep

This template will be included below the form on the C</register> page.

=item * vendor/wizard.html.ep

This template will be included below the form on the C</wizard> page that a
new visitor sees after registering.

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

=item * L<Convos::Controller::Client>

Mojolicious controller for IRC chat.

=item * L<Convos::Controller::User>

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

our $VERSION = '0.8602';

$ENV{CONVOS_DEFAULT_CONNECTION} //= 'chat.freenode.net:6697';

=head1 ATTRIBUTES

=head2 core

Holds a L<Convos::Core> object .

=head2 upgrader

DEPRECATED.

=cut

has core => sub {
  my $self = shift;
  my $core = Convos::Core->new(redis => $self->redis);

  $core->log($self->log);
  $core->archive->log_dir($ENV{CONVOS_ARCHIVE_DIR} || $self->home->rel_dir('irc_logs'));
  $core;
};

has upgrader => sub { die "upgrader() is deprecated" };

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;
  my $config;

  $self->{convos_executable_path} = $0;    # required to work from within toadfarm
  $self->_from_cpan;
  $config = $self->_config;

  if (my $log = $config->{log}) {
    $self->log->level($log->{level}) if $log->{level};
    $self->log->path($log->{file}) if $log->{file} ||= $log->{path} || $ENV{CONVOS_FRONTEND_LOGFILE};
    delete $self->log->{handle};           # make sure it's fresh to file
  }

  $self->ua->max_redirects(2);             # support getting facebook pictures
  $self->plugin('Convos::Plugin::Helpers');
  $self->plugin('LinkEmbedder');
  $self->secrets([time]);                  # will be replaced by _set_secrets()
  $self->_redis_url;

  return if $ENV{CONVOS_BACKEND_ONLY};     # set script/convos when started as backend

  # frontend code
  $self->sessions->default_expiration(86400 * 30);
  $self->sessions->secure(1) if $ENV{CONVOS_SECURE_COOKIES};
  $self->_assets;
  $self->_public_routes;
  $self->_private_routes;

  if (!$ENV{CONVOS_INVITE_CODE} and $config->{invite_code}) {
    $self->log->warn(
      "invite_code from config file will be deprecated. Set the CONVOS_INVITE_CODE env variable instead.");
    $ENV{CONVOS_INVITE_CODE} = $config->{invite_code};
  }
  if ($ENV{CONVOS_TEMPLATES}) {

    # Using push() since I don't think it's a good idea for allowing the user
    # to customize every template, at least not when the application is still
    # unstable.
    push @{$self->renderer->paths}, $ENV{CONVOS_TEMPLATES};
  }

  $self->defaults(full_page => 1, organization_name => $self->config('name'));
  $self->hook(before_dispatch => \&_before_dispatch);
  $self->_embed_backend if $ENV{CONVOS_BACKEND_EMBEDDED};

  Scalar::Util::weaken($self);
  Mojo::IOLoop->timer(0 => sub { $self->_set_secrets });
}

sub _assets {
  my $self = shift;

  $self->plugin('AssetPack');
  $self->plugin('FontAwesome4', css => []);
  $self->asset('c.css' => qw( /scss/font-awesome.scss /sass/convos.scss ));
  $self->asset(
    'c.js' => qw(
      https://platform.twitter.com/widgets.js
      /js/globals.js
      /js/jquery.js
      /js/ws-reconnecting.js
      /js/jquery.hotkeys.js
      /js/jquery.finger.js
      /js/jquery.pjax.js
      /js/jquery.notify.js
      /js/jquery.disableouterscroll.js
      /js/convos.events.js
      /js/convos.sidebar.js
      /js/convos.socket.js
      /js/convos.input.js
      /js/convos.conversations.js
      /js/convos.nicks.js
      /js/convos.goto-anything.js
      /js/convos.chat.js
      )
  );
}

sub _before_dispatch {
  my $c = shift;

  $c->stash(full_page => !($c->req->is_xhr || $c->param('_pjax')));

  if (my $base = $c->req->headers->header('X-Request-Base')) {
    $c->req->url->base(Mojo::URL->new($base));
  }
  if (!$c->app->config->{hostname_is_set}++) {
    $c->redis->set('convos:frontend:url' => $c->req->url->base->to_abs->to_string);
  }
}

sub _config {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : $self->config;

  $config->{hypnotoad}{listen} ||= [split /,/, $ENV{MOJO_LISTEN} || 'http://*:8080'];
  $config->{hypnotoad}{pid_file} = $ENV{CONVOS_FRONTEND_PID_FILE} if $ENV{CONVOS_FRONTEND_PID_FILE};
  $config->{hypnotoad}{group}    = $ENV{RUN_AS_GROUP}             if $ENV{RUN_AS_GROUP};
  $config->{hypnotoad}{user}     = $ENV{RUN_AS_USER}              if $ENV{RUN_AS_USER};
  $config->{name}                = $ENV{CONVOS_ORGANIZATION_NAME} if $ENV{CONVOS_ORGANIZATION_NAME};
  $config->{name} ||= 'Nordaaker';
  $config;
}

sub _embed_backend {
  my $self = shift;

  die "Cannot start embedded backend from hypnotoad" if $SIG{USR2};
  require Convos::Control::Backend;
  my $backend = Convos::Control::Backend->new;

  $backend->read_pid;

  if ($backend->pid and $backend->pid_running) {
    $self->app->log->warn('Backend is already running.');
  }
  else {
    $backend->pid($$);
    $backend->write_pid;
    $self->{pid_file} = $backend->pid_file;
    $self->log->info('Starting convos backend.');
    $self->core->start;
  }
}

sub _from_cpan {
  my $self = shift;
  my $home = catdir dirname(__FILE__), 'Convos';

  return if -d $self->home->rel_dir('templates');
  $self->home->parse($home);
  $self->static->paths->[0]   = $self->home->rel_dir('public');
  $self->renderer->paths->[0] = $self->home->rel_dir('templates');
}

sub _private_routes {
  my $self = shift;
  my $r = $self->routes->under('/')->to('user#auth', layout => 'view');

  $r->websocket('/socket')->to('chat#socket')->name('socket');
  $r->get('/chat/command-history')->to('client#command_history');
  $r->get('/chat/notifications')->to('client#notifications', layout => undef)->name('notification.list');
  $r->post('/chat/notifications/clear')->to('client#clear_notifications', layout => undef)->name('notifications.clear');
  $r->any('/connection/add')->to('connection#add_connection')->name('connection.add');
  $r->any('/connection/:name/control')->to('connection#control')->name('connection.control');
  $r->any('/connection/:name/edit')->to('connection#edit_connection')->name('connection.edit');
  $r->get('/connection/:name/delete')->to(template => 'connection/delete_connection', layout => 'tactile');
  $r->post('/connection/:name/delete')->to('connection#delete_connection')->name('connection.delete');
  $r->get('/oembed')->to('oembed#generate', layout => undef)->name('oembed');
  $r->any('/profile')->to('user#edit')->name('user.edit');
  $r->any('/profile/delete')->to('user#delete')->name('user.delete');
  $r->post('/profile/timezone/offset')->to('user#tz_offset');
  $r->get('/wizard')->to('connection#wizard')->name('wizard');

  my $network_r = $r->any('/:network');
  $network_r->get('/*target' => [target => qr/[\#\&][^\x07\x2C\s]{1,50}/])->to('client#conversation', is_channel => 1)
    ->name('view');
  $network_r->get('/*target' => [target => qr/[A-Za-z_\-\[\]\\\^\{\}\|\`][A-Za-z0-9_\-\[\]\\\^\{\}\|\`]{1,15}/])
    ->to('client#conversation', is_channel => 0)->name('view');
  $network_r->get('/')->to('client#conversation')->name('view.network');
}

sub _public_routes {
  my $self = shift;
  my $r = $self->routes->any->to(layout => 'tactile');

  $r->get('/')->to('client#route')->name('index');
  $r->get('/convos')->to(cb => sub { shift->redirect_to('index'); });
  $r->get('/avatar')->to('user#avatar')->name('avatar');
  $r->get('/login')->to('user#login')->name('login');
  $r->post('/login')->to('user#login');
  $r->get('/register/:invite', {invite => ''})->to('user#register')->name('register');
  $r->post('/register/:invite', {invite => ''})->to('user#register');
  $r->get('/logout')->to('user#logout')->name('logout');
  $r;
}

sub _redis_url {
  my $self = shift;
  my $url;

  for my $k (qw( CONVOS_REDIS_URL REDISTOGO_URL REDISCLOUD_URL DOTCLOUD_DATA_REDIS_URL )) {
    $url = $ENV{$k} or next;
    $self->log->debug("Using $k environment variable as Redis connection URL.");
    last;
  }

  unless ($url) {
    if ($self->config('redis')) {
      $self->log->warn("'redis' url from config file will be deprecated. Run 'perldoc Convos' for alternative setup.");
      $url = $self->config('redis');
    }
    elsif ($self->mode eq 'production') {
      $self->log->debug("Using default Redis connection URL redis://127.0.0.1:6379/1");
      $url = 'redis://127.0.0.1:6379/1';
    }
    else {
      $self->log->debug("Could not find CONVOS_REDIS_URL value.");
      return;
    }
  }

  $url = Mojo::URL->new($url);
  $url->path($ENV{CONVOS_REDIS_INDEX}) if $ENV{CONVOS_REDIS_INDEX} and !$url->path->[0];
  $ENV{CONVOS_REDIS_URL} = $url->to_string;
}

sub _set_secrets {
  my $self  = shift;
  my $redis = $self->redis;

  $self->delay(
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

sub DESTROY {
  my $self     = shift;
  my $pid_file = $self->{pid_file};

  unlink $pid_file if $pid_file and -r $pid_file;
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
