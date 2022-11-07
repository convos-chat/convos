package Convos;
use Mojo::Base 'Mojolicious';

use Carp qw(croak);
use Cwd  ();
use Convos::Core;
use Convos::Util  qw(is_true require_module);
use File::HomeDir ();
use Mojo::File    qw(path);
use Mojo::JSON    qw(false true);
use Mojo::Util;
use Scalar::Util qw(blessed);

use constant CONVOS_GET => +($ENV{CONVOS_COMMAND} || '') eq 'get';

our $VERSION = '7.12';

$ENV{CONVOS_REVERSE_PROXY} //= is_true 'ENV:MOJO_REVERSE_PROXY';
$ENV{MOJO_REVERSE_PROXY}   //= is_true 'ENV:CONVOS_REVERSE_PROXY';

has core => sub {
  my $self = shift;
  my $home = Cwd::abs_path($self->config('home')) || $self->config('home');

  return Convos::Core->new(
    backend => $self->config('backend'),
    home    => path(split '/', $home),
    log     => $self->log,
  );
};

sub startup {
  my $self   = shift;
  my $config = $self->_config;

  $self->_home_in_share unless -d $self->home->rel_file('public');
  $self->_patch_mojo_promise if $ENV{MOJO_PROMISE_CROAK};
  $self->defaults(existing_user => 0, lang => 'en', start_app => '');
  $self->routes->namespaces(['Convos::Controller']);
  $self->sessions->cookie_name('convos');
  $self->sessions->default_expiration(86400 * 7);
  $self->types->type(yaml => $self->types->type('txt'));
  push @{$self->renderer->classes}, __PACKAGE__;

  # Autogenerate routes from the OpenAPI specification
  my $api_route = $self->routes->under('/')->to('user#check_if_ready', openapi => 1);
  $self->plugin(
    OpenAPI => {
      format => ['json'],
      route  => $api_route,
      url    => $self->static->file('convos-api.yaml')->path
    }
  );

  # Add basic routes
  my $r                  = $self->routes;
  my @format_constraints = (format => [qw(html json txt yaml)]);
  $r->get('/',     [@format_constraints])->to('cms#index',     format => undef)->name('index');
  $r->get('/blog', [@format_constraints])->to('cms#blog_list', format => undef);
  $r->get('/blog/:year/:mon/:mday/:name', [@format_constraints])
    ->to('cms#blog_entry', format => undef, page => 1)->name('blog_entry');
  $r->get('/doc/*file', [@format_constraints])->to('cms#doc', file => 'index', format => undef)
    ->name('doc');
  $r->get('/logout', [format => [qw(html json)]])->to('user#logout', format => undef);
  $r->get('/assets/browserconfig.<:hash>', [format => ['xml']])
    ->to(template => 'assets/browserconfig');
  $r->get('/assets/site.<:hash>', [format => ['webmanifest']])->to(template => 'assets/site');
  $r->get('/err/500')->to(cb => sub { die 'Test 500 page' });
  $r->get('/err/:code')->to('url#err');
  $r->get('/sw'      => [format => 'js']);
  $r->get('/sw/info' => {json => {mode => $self->mode, version => $self->VERSION}});
  $r->get('/video/#domain/:name')->to(cb => sub { shift->render('video') });

  # Friendly alias for /api/file/:uid/:fid
  $r->get('/file/:uid/:fid', [format => 1])->to('files#get');

  # Event channel
  $r->websocket('/events')->to('events#start')->name('events');

  # Chat resources
  my $user_r = $r->under('/')->to('user#check_if_ready');
  $user_r->get('/help');
  $user_r->get('/chat')->name('chat');
  $user_r->get('/chat/:connection_id')->name('chat.connection_id');
  $user_r->get('/chat/:connection_id/#conversation_id')->name('chat.connection_id.conversation_id');
  $user_r->get('/login');
  $user_r->get('/register')->to('user#register_html');
  $user_r->get('/settings/*rest', {rest => ''});
  $user_r->get('/search');

  $self->_plugins;
  $self->hook(around_action   => \&_around_action);
  $self->hook(after_build_tx  => \&_after_build_tx);
  $self->hook(before_dispatch => \&_before_dispatch);
  $self->core->start;
}

sub _after_build_tx {
  my ($tx, $app) = @_;
  $tx->req->max_message_size($ENV{CONVOS_MAX_UPLOAD_SIZE} // 40_000_000);
}

sub _around_action {
  my ($next, $c, $action, $last) = @_;
  my $res = $c->$next;
  $c->render_later if blessed $res and $res->can('then');
  return $res;
}

sub _before_dispatch {
  my $c = shift;

  # Handle /whatever/with%2Fslash/...
  my $path     = $c->req->url->path;
  my $path_str = "$path";
  $path_str =~ s/%([0-9a-fA-F]{2})/{my $h = hex $1; $h == 47 ? '%2F' : chr $h}/ge;
  $path->leading_slash(1)  if $path_str =~ s!^/!!;
  $path->trailing_slash(1) if $path_str =~ s!/$!!;
  $path->parts([
    split '/', $path->charset ? Mojo::Util::decode($path->charset, $path_str) : $path_str
  ]);

  # Handle mount point like /apps/convos
  my ($base_url, $env_missing) = ($c->req->headers->header('X-Request-Base'), 0);
  if ($base_url) {
    $base_url    = Mojo::URL->new($base_url);
    $env_missing = !$ENV{CONVOS_REVERSE_PROXY};
    $c->req->url->base($base_url) if is_true 'ENV:CONVOS_REVERSE_PROXY';
  }
  elsif ($ENV{CONVOS_REQUEST_BASE}) {
    $base_url = Mojo::URL->new($ENV{CONVOS_REQUEST_BASE});
    $c->req->url->base($base_url);
  }

  my $settings = $c->app->core->settings;
  $base_url ||= $c->req->url->to_abs->query(Mojo::Parameters->new)->path('/');
  $settings->save_p({base_url => $base_url}) if !CONVOS_GET and $settings->base_url ne $base_url;
  $c->app->sessions->secure(is_true('ENV:CONVOS_SECURE_COOKIES')
      || $base_url->scheme eq 'https' ? 1 : 0);
  $c->res->headers->header('X-Provider-Name', 'ConvosApp');

  # Used when registering the first user
  $c->stash(first_user => !$c->app->core->n_users);

  # App settings
  $c->stash($settings->TO_JSON);

  $c->reply->exception('X-Request-Base header was seen, but CONVOS_REVERSE_PROXY is not set')
    if $env_missing;
}

sub _config {
  my $self   = shift;
  my $config = $self->config;

  $config->{backend} ||= $ENV{CONVOS_BACKEND} || 'Convos::Core::Backend::File';
  $config->{home}    ||= $ENV{CONVOS_HOME}
    ||= path(File::HomeDir->my_home, qw(.local share convos))->to_string;

  if ($config->{log_file} ||= $ENV{CONVOS_LOG_FILE}) {
    $self->log->path($config->{log_file});
    delete $self->log->{handle};
  }

  my $access_log = $ENV{CONVOS_ACCESS_LOG} // 'v2';
  my $enabled    = is_true 'ENV:CONVOS_SYSLOG';
  $self->plugin(Syslog => {access_log => $access_log, enable => $enabled, only_syslog => $enabled});

  $self->log->level($ENV{CONVOS_LOG_LEVEL});
  $self->log->info(qq(CONVOS_HOME="$config->{home}" # https://convos.chat/doc/config#convos_home"));

  my $settings = $self->core->settings;
  $settings->load_p->wait;
  $self->secrets($settings->session_secrets);
  $settings->save_p->wait;

  return $config;
}

sub _home_in_share {
  my $self = shift;
  my $rel  = path(qw(auto share dist Convos))->to_string;

  for my $inc (@INC) {
    next if ref $inc or !$inc;
    my $share = path($inc, $rel);
    next unless -d $share and -r _;
    ${$self->home} = $share->to_string;
    $self->static->paths->[0] = $share->child('public')->to_string;
    return $self;
  }

  die "Unable to find $rel in @INC";
}

sub _patch_mojo_promise {
  require Mojo::Promise;

  Mojo::Util::monkey_patch(
    'Mojo::Promise',
    AWAIT_GET => sub {
      my $self    = shift;
      my @results = @{$self->{results} // []};
      croak $results[0] unless $self->{status} eq 'resolve';
      return wantarray ? @results : $results[0];
    }
  );
}

sub _plugins {
  my $self = shift;
  unshift @{$self->plugins->namespaces}, 'Convos::Plugin';

  my @plugins = (
    qw(Convos::Plugin::Auth Convos::Plugin::Bot Convos::Plugin::Cms),
    qw(Convos::Plugin::I18N Convos::Plugin::Helpers Convos::Plugin::Paste),
    qw(Convos::Plugin::Themes),
  );

  push @plugins, split /,/, $ENV{CONVOS_PLUGINS} if $ENV{CONVOS_PLUGINS};

  for (@plugins) {
    my ($name, $config) = split '\?', $_, 2;
    $self->plugin($name => Mojo::Parameters->new($config // '')->to_hash);
  }
}

1;

=encoding utf8

=head1 NAME

Convos - Multiuser chat application

=head1 VERSION

7.12

=head1 DESCRIPTION

L<Convos> is a multiuser chat application built with L<Mojolicious>.

It currently support the IRC protocol, but can be extended to support
other protocols as well. Below is a list of the main documentation
starting points for Convos:

=over 2

=item * L<Documentation index|https://convos.chat/doc/>

=item * L<Getting started|https://convos.chat/doc/start>

=item * L<Development guide|https://convos.chat/doc/develop>

=item * L<REST API reference|https://convos.chat/api>

=back

=head2 Reference

This is the module and documentation structure of L<Convos>:

=over 2

=item * L<Convos::Core>

=over 2

=item * L<Convos::Core::Backend>

=over 2

=item * L<Convos::Core::Backend::File>

=back

=item * L<Convos::Core::Connection>

=over 2

=item * L<Convos::Core::Connection::Irc>

=back

=item * L<Convos::Core::Conversation>

=item * L<Convos::Core::User>

=back

=item * I<Convos::Controller>

=over 2

=item * L<Convos::Controller::Connection>

=item * L<Convos::Controller::Conversation>

=item * L<Convos::Controller::Events>

=item * L<Convos::Controller::Notifications>

=item * L<Convos::Controller::User>

=back

=back

=head1 ATTRIBUTES

L<Convos> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 core

Holds a L<Convos::Core> object.

=head1 METHODS

L<Convos> inherits all methods from L<Mojolicious> and implements
the following new ones.

=head2 startup

This method sets up the application.

=head1 COPYRIGHT AND LICENSE

=head2 Material design icons

The icons used are provided by L<Google|https://www.google.com/design/icons>
under the L<CC-BY license|https://creativecommons.org/licenses/by/4.0/>.

=head2 Convos core and frontend

Copyright Convos Org.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHORS

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut
