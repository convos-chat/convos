package Convos::Plugin::Helpers;
use Mojo::Base 'Convos::Plugin';

use Convos::Util qw(E pretty_connection_name);
use LinkEmbedder;
use Mojo::JSON qw(false true);
use Mojo::Util 'url_unescape';

my @LOCAL_ADMIN_REMOTE_ADDR = split /,/, ($ENV{CONVOS_LOCAL_ADMIN_REMOTE_ADDR} || '127.0.0.1,::1');

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('asset_version'             => \&_asset_version);
  $app->helper('backend.dialog'            => \&_backend_dialog);
  $app->helper('backend.user'              => \&_backend_user);
  $app->helper('backend.connection_create' => \&_backend_connection_create);
  $app->helper('linkembedder'              => sub { state $l = LinkEmbedder->new });
  $app->helper('settings'                  => \&_settings);
  $app->helper('unauthorized'              => \&_unauthorized);
  $app->helper('user_has_admin_rights'     => \&_user_has_admin_rights);
}

sub _asset_version {
  my $app = shift->app;
  return $app->config->{asset_version} if $app->config->{asset_version};

  my $mode  = $app->mode eq 'development' ? 'development' : 'production';
  my @paths = (
    $app->static->file("asset/webpack.$mode.html")->path,
    $app->renderer->template_path({template => 'sw', format => 'js', handler => 'ep'}),
  );

  my $version = 0;
  for my $path (@paths) {
    my $mtime = (stat $path)[9];
    $version = $mtime if $mtime > $version;
  }

  return $version if $mode eq 'development';
  return $app->config->{asset_version} = $version;
}

sub _backend_dialog {
  my ($c, $args) = @_;
  my $user      = $c->backend->user($args->{email}) or return;
  my $dialog_id = url_unescape $args->{dialog_id} || $c->stash('dialog_id') || '';

  my $connection = $user->get_connection($args->{connection_id} || $c->stash('connection_id'));
  return unless $connection;

  my $dialog = $dialog_id ? $connection->get_dialog($dialog_id) : $connection->messages;
  return $c->stash(connection => $connection, dialog => $dialog)->stash('dialog');
}

sub _backend_user {
  my $c = shift;
  return undef unless my $email = shift || $c->session('email');
  return $c->app->core->get_user({email => $email});
}

sub _backend_connection_create {
  my ($c, $url, $cb) = @_;
  my $user = $c->backend->user;
  my $name = pretty_connection_name($url->host);
  my $connection;

  if (!$name) {
    return $c->$cb('URL need a valid host.', undef);
  }
  if ($user->get_connection({protocol => $url->scheme, name => $name})) {
    return $c->$cb('Connection already exists.', undef);
  }

  Mojo::IOLoop->delay(
    sub {
      $connection = $user->connection({name => $name, protocol => $url->scheme, url => $url});
      $connection->dialog({name => $url->path->[0]}) if $url->path->[0];
      $connection->save(shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      return $c->$cb($err, $connection);
    },
  )->catch(sub {
    return $c->$cb(pop, undef);
  });
}

sub _settings {
  my $c = shift;

  # Set
  if (@_ == 2) {
    $c->stash->{'convos.settings'}{$_[0]} = $_[1];
    return $c;
  }

  # Get
  my $app      = $c->app;
  my $extra    = $c->stash('convos.settings') || {};
  my %settings = %{$c->app->config('settings') || {}};
  $settings{apiUrl}       = $c->url_for('api');
  $settings{assetVersion} = $c->asset_version;
  $settings{baseUrl}      = $c->app->core->base_url->to_string;
  $settings{loadUser}     = $c->stash('load_user') ? true : false;
  $settings{status}       = int($c->stash('status') || 200);
  $settings{wsUrl}        = $c->url_for('events')->to_abs->userinfo(undef)->to_string;
  $settings{$_}           = $extra->{$_} for keys %$extra;
  return \%settings;
}

sub _unauthorized {
  shift->render(json => E('Need to log in first.'), status => 401);
}

sub _user_has_admin_rights {
  my $c              = shift;
  my $x_local_secret = $c->req->headers->header('X-Local-Secret');

  # Normal request from web
  unless ($x_local_secret) {
    my $admin_user = $c->backend->user;
    return +($admin_user && $admin_user->role(has => 'admin')) ? 'user' : '';
  }

  # Special request for forgotten password
  my $remote_address = $c->tx->original_remote_address;
  my $valid          = $x_local_secret eq $c->app->config->{local_secret} ? 1 : 0;
  my $valid_str      = $valid ? 'Valid' : 'Invalid';
  $c->app->log->warn("$valid_str X-Local-Secret from $remote_address (@LOCAL_ADMIN_REMOTE_ADDR)");
  return +($valid && grep { $remote_address eq $_ } @LOCAL_ADMIN_REMOTE_ADDR) ? 'local' : '';
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Helpers - Default helpers for Convos

=head1 DESCRIPTION

This L<Convos::Plugin> contains default helpers for L<Convos>.

=head1 HELPERS

=head2 backend.dialog

  $dialog = $c->backend->dialog(\%args);

Helper to retrieve a L<Convos::Core::Dialog> object. Will use
data from C<%args> or fall back to L<stash|Mojolicious/stash>. Example
C<%args>:

  {
    # Key         => Example value        # Default value
    connection_id => "irc-localhost",     # $c->stash("connection_id")
    dialog_id     => "#superheroes",      # $c->stash("connection_id")
    email         => "superwoman@dc.com", # $c->session('email')
  }

=head2 backend.user

  $user = $c->backend->user($email);
  $user = $c->backend->user;

Used to return a L<Convos::User> object representing the logged in user
or a user with email C<$email>.

=head2 unauthorized

  $c = $c->unauthorized;

Used to render an OpenAPI response with status code 401.

=head1 METHODS

=head2 register

  $self->register($app, \%config);

Called by L<Convos>, when registering this plugin.

=head1 SEE ALSO

L<Convos>.

=cut
