package Convos::Plugin::Helpers;
use Mojo::Base 'Convos::Plugin';

use Convos::Util 'pretty_connection_name';
use JSON::Validator::Error;
use LinkEmbedder;
use Mojo::JSON qw(decode_json false true);
use Mojo::Util qw(b64_decode url_unescape);

my @LOCAL_ADMIN_REMOTE_ADDR = split /,/, ($ENV{CONVOS_LOCAL_ADMIN_REMOTE_ADDR} || '127.0.0.1,::1');
my $EXCEPTION_HELPER;

sub register {
  my ($self, $app, $config) = @_;

  $EXCEPTION_HELPER = $app->renderer->get_helper('reply.exception');

  $app->helper('asset_version'               => \&_asset_version);
  $app->helper('backend.dialog'              => \&_backend_dialog);
  $app->helper('backend.user'                => \&_backend_user);
  $app->helper('backend.connection_create_p' => \&_backend_connection_create_p);
  $app->helper('js_session'                  => \&_js_session);
  $app->helper('l'                           => \&_l);
  $app->helper('linkembedder'                => sub { state $l = LinkEmbedder->new });
  $app->helper('settings'                    => \&_settings);
  $app->helper('reply.errors'                => \&_reply_errors);
  $app->helper('reply.exception'             => \&_exception);
  $app->helper('social'                      => \&_social);
  $app->helper('user_has_admin_rights'       => \&_user_has_admin_rights);

  $app->linkembedder->ua->insecure(1) if $ENV{LINK_EMBEDDER_ALLOW_INSECURE_SSL};
  $app->linkembedder->ua->$_(5) for qw(connect_timeout inactivity_timeout request_timeout);
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

sub _backend_connection_create_p {
  my ($c, $url) = @_;
  my $user = $c->backend->user;

  return Mojo::Promise->reject('URL need a valid host.')
    unless my $name = pretty_connection_name($url);

  return Mojo::Promise->reject('Connection already exists.')
    if $user->get_connection({protocol => $url->scheme, name => $name});

  eval {
    my $connection = $user->connection({name => $name, protocol => $url->scheme, url => $url});
    $connection->dialog({name => $url->path->[0]}) if $url->path->[0];
    return $connection->save_p;
  } or do {
    return Mojo::Promise->reject($@);
  };
}

sub _exception {
  my ($c, $err) = @_;
  return $EXCEPTION_HELPER->($c, $err) unless $c->openapi->spec;
  $c->app->log->error($err);
  $err =~ s!\sat\s\S+.*!!s;
  return $c->render(openapi => {errors => [{message => "$err", path => '/'}]}, status => 500);
}

sub _js_session {
  my ($c, $name) = @_;
  my $stash = $c->stash;
  return $name ? $stash->{'convos.js.session'}{$name} : $stash->{'convos.js.session'}
    if $stash->{'convos.js.session'};

  my $cookie = $c->cookie('convos_js');
  $cookie = $cookie ? decode_json b64_decode $cookie : undef;
  $stash->{'convos.js.session'} = $cookie || {};
  return _js_session($c, $name);
}

sub _l {
  my ($self, $lexicon, @args) = @_;
  $lexicon =~ s!%(\d+)!{$args[$1 - 1] // $1}!ge;
  return $lexicon;
}

sub _reply_errors {
  my ($self, $errors, $status) = @_;

  $errors = [["$errors"]] unless ref $errors eq 'ARRAY';
  $errors = [
    map {
      my ($msg, $path) = @$_;
      $msg =~ s! at \S+.*!!s;
      $msg =~ s!:\s.*!.!s;
      JSON::Validator::Error->new($path || '/', $msg);
    } @$errors
  ];

  $status ||= 501;
  $errors->[0] = JSON::Validator::Error->new('/', 'Need to log in first.')
    if $status == 401 and !@$errors;

  $self->render(json => {errors => $errors}, status => $status);
  return undef;
}

sub _settings {
  my $c        = shift;
  my $settings = $c->stash->{'convos.settings'} ||= _setup_settings($c);

  # Set
  if (@_ == 2) {
    $settings->{$_[0]} = $_[1];
    return $c;
  }

  # Get single key
  if (@_ == 1) {
    my $key = shift;
    return exists $settings->{$key} ? $settings->{$key} : $c->app->core->settings->$key;
  }

  # Get all public settings
  $settings->{load_user} = $c->stash('load_user') ? true : false;
  $settings->{status}    = int($c->stash('status') || 200);

  return $settings;
}

sub _setup_settings {
  my $c        = shift;
  my $app      = $c->app;
  my $settings = $app->core->settings;

  my $defaults = $settings->defaults;
  my $defined  = $settings->TO_JSON;
  $defined->{$_} ||= $defaults->{$_} for keys %$defaults;

  $defined->{api_url}       = $c->url_for('api');
  $defined->{asset_version} = $c->asset_version;
  $defined->{base_url}      = $app->core->base_url->to_string;
  $defined->{mode}          = $app->mode;
  $defined->{themes}        = $c->themes->get;
  $defined->{version}       = $app->VERSION;
  $defined->{ws_url}        = $c->url_for('events')->to_abs->userinfo(undef)->to_string;

  return $defined;
}

sub _social {
  my $c      = shift;
  my $social = $c->stash->{social} ||= {};

  # Defaults
  $social->{description} ||= 'A chat application that runs in your web browser';
  $social->{image}       ||= $c->url_for('/images/2020-05-28-convos-chat.jpg')->to_abs;
  $social->{url}         ||= $c->url_for('/')->to_abs;

  # Get
  return $social unless @_;

  # Set
  $social->{$_[0]} = $_[1];
  return $c;
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
  my $valid          = $x_local_secret eq $c->settings('local_secret') ? 1 : 0;
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

=head2 reply.errors

  undef = $c->reply->errors([], 401);
  undef = $c->reply->errors([[$msg, $path], ...], $status);
  undef = $c->reply->errors($msg, $status);

Used to render an OpenAPI error response.

=head1 METHODS

=head2 register

  $plugin->register($app, \%config);

Called by L<Convos>, when registering this plugin.

=head1 SEE ALSO

L<Convos>.

=cut
