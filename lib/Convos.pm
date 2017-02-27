package Convos;
use Mojo::Base 'Mojolicious';

use Cwd ();
use Convos::Core;
use Convos::Util;
use File::HomeDir ();
use Mojo::File 'path';
use Mojo::JSON qw(false true);
use Mojo::Util;

our $VERSION = '0.99_26';

has core => sub {
  my $self = shift;
  my $home = Cwd::abs_path($self->config('home')) || $self->config('home');

  return Convos::Core->new(backend => $self->config('backend'), home => Mojo::Home->new($home));
};

has _api_spec => sub {
  my $self = shift;
  my $file = $self->static->file('convos-api.json');
  die "Could not find convos-api.json in static=@{$self->static->paths}, home=@{[$self->home]})"
    unless $file;
  return Mojo::JSON::decode_json(path($file->path)->slurp);
};

has _custom_assets => sub { Mojolicious::Static->new };
has _link_cache => sub { Mojo::Cache->new->max_keys($ENV{CONVOS_MAX_LINK_CACHE_SIZE} || 100) };

sub extend_api_spec {
  my ($self, $path) = (shift, shift);

  while (@_) {
    my ($method, $op) = (shift, shift);

    $op->{responses}{default}
      ||= {description => 'Error.', schema => {'$ref' => '#/definitions/Error'}};

    if (my $cb = delete $op->{cb}) {
      $self->{anon} ||= do { state $i; ++$i };
      my $ctrl = "Convos::Controller::Anon$self->{anon}";
      eval "package $ctrl; use Mojo::Base 'Mojolicious::Controller'; 1" or die $@;
      Mojo::Util::monkey_patch($ctrl => $op->{operationId} => $cb);
      $op->{'x-mojo-to'} = sprintf 'anon%s#%s', $self->{anon}, $op->{operationId};
    }

    $self->_api_spec->{paths}{$path}{$method} = $op;
  }

  return $self;
}

sub startup {
  my $self   = shift;
  my $config = $self->_config;
  my $r      = $self->routes;

  $self->_home_in_share unless -d $self->home->rel_file('public');
  $self->defaults(debug => $self->mode eq 'development' ? ['info'] : []);
  $self->routes->namespaces(['Convos::Controller']);
  $self->sessions->cookie_name('convos');
  $self->sessions->default_expiration(86400 * 7);
  $self->sessions->secure(1) if $config->{secure_cookies};
  push @{$self->renderer->classes}, __PACKAGE__;

  # Add basic routes
  $r->get('/')->to(template => 'convos')->name('index');
  $r->get('/custom/asset/*file' => \&_action_custom_asset);
  $r->websocket('/events')->to('events#start')->name('events');

  $self->_api_spec;
  $self->_plugins;
  $self->_setup_secrets;

  # Autogenerate routes from the OpenAPI specification
  $self->plugin(OpenAPI => {url => delete $self->{_api_spec}});

  # Expand links into rich content
  $self->plugin('LinkEmbedder');

  # Add /perldoc route for documentation
  $self->plugin('PODRenderer')->to(module => 'Convos');

  # Skip building on travis
  $ENV{TRAVIS_BUILD_ID} ? $self->helper(asset => sub { }) : $self->_assets;

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      my $base = $c->req->headers->header('X-Request-Base') or return;
      $c->req->url->base(Mojo::URL->new($base));
    }
  );

  $self->core->start;
}

# Used internally to generate dynamic SASS files
sub _action_custom_asset {
  my $c      = shift;
  my $static = $c->app->_custom_assets;
  my $asset  = $static->file(Mojo::Path->new($c->stash('file'))->canonicalize);

  # Can never render 404, since that will make AssetPack croak
  return $c->render(text => "// not found\n", status => 200) unless $asset;
  $c->app->log->info('Loading custom asset: ' . $asset->path);
  $static->serve_asset($c, $asset);
  $c->rendered;
}

sub _assets {
  my $self          = shift;
  my $custom_assets = $self->core->home->rel_file('assets');

  $self->plugin(AssetPack => {pipes => [qw(Favicon Vuejs JavaScript Sass Css Combine Reloader)]});

  if (-d $custom_assets) {
    $self->log->info("Including files from $custom_assets when building frontend.");
    $self->_custom_assets->paths([$custom_assets]);
    unshift @{$self->asset->store->paths}, $custom_assets;
  }

  $self->asset->pipe('Favicon')
    ->api_key($ENV{REALFAVICONGENERATOR_API_KEY} || 'REALFAVICONGENERATOR_API_KEY=is_not_set')
    ->design({desktop_browser => {}, ios => {}});
  $self->asset->process('favicon.ico' => 'images/icon.svg');
  $self->asset->process;
}

sub _config {
  my $self   = shift;
  my $config = $self->config;

  if (my $path = $ENV{MOJO_CONFIG}) {
    $config = $path =~ /\.json$/ ? $self->plugin('JSONConfig') : $self->plugin('Config');
  }

  $config->{backend}           ||= $ENV{CONVOS_BACKEND}           || 'Convos::Core::Backend::File';
  $config->{contact}           ||= $ENV{CONVOS_CONTACT}           || 'mailto:root@localhost';
  $config->{default_server}    ||= $config->{forced_irc_server}   || $ENV{CONVOS_DEFAULT_SERVER};
  $config->{forced_irc_server} ||= $ENV{CONVOS_FORCED_IRC_SERVER} || '';
  $config->{home}
    ||= $ENV{CONVOS_HOME} || path(File::HomeDir->my_home, qw(.local share convos))->to_string;
  $config->{organization_url}  ||= $ENV{CONVOS_ORGANIZATION_URL}  || 'http://convos.by';
  $config->{organization_name} ||= $ENV{CONVOS_ORGANIZATION_NAME} || 'Convos';
  $config->{secure_cookies}    ||= $ENV{CONVOS_SECURE_COOKIES}    || 0;

  # public settings
  $config->{settings} = {
    contact           => $config->{contact},
    default_server    => $config->{default_server},
    forced_irc_server => $config->{forced_irc_server} ? true : false,
    organization_name => $config->{organization_name},
    organization_url  => $config->{organization_url},
    version => $self->VERSION || '0.01',
  };

  $config;
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

sub _plugins {
  my $self    = shift;
  my $plugins = $self->config('plugins');
  my @plugins = !$plugins ? () : ref $plugins eq 'ARRAY' ? @$plugins : %$plugins;
  my %uniq;

  unshift @{$self->plugins->namespaces}, 'Convos::Plugin';
  unshift @plugins, split /,/, $ENV{CONVOS_PLUGINS} if $ENV{CONVOS_PLUGINS};
  unshift @plugins, qw(Convos::Plugin::Auth Convos::Plugin::Helpers);

  while (@plugins) {
    my $name = shift @plugins or last;
    my $config = ref $plugins[0] ? shift @plugins : {};
    $self->plugin($name => $config) unless $uniq{$name}++;
  }
}

sub _setup_secrets {
  my $self = shift;
  my $secrets = $self->config('secrets') || [split /,/, $ENV{CONVOS_SECRETS} || ''];

  unless (@$secrets) {
    my $unsafe = join ':', $<, $(, $^X, qx{who -b 2>/dev/null}, $self->home;
    $self->log->warn('Using default (unsafe) session secrets. (Config file was not set up)');
    $secrets = [Mojo::Util::md5_sum($unsafe)];
  }

  $self->secrets($secrets);
}

1;

=encoding utf8

=head1 NAME

Convos - Multiuser chat application

=head1 VERSION

0.99_26

=head1 DESCRIPTION

L<Convos> is a multiuser chat application built with L<Mojolicious>.

It currently support the IRC protocol, but can be extended to support
other protocols as well. Below is a list of the main documentation
starting points for Convos:

=over 2

=item * L<Convos::Guides::Running>

=item * L<Convos::Guides::Development>

=item * L<Convos::Guides::API>

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

=item * L<Convos::Core::Dialog>

=item * L<Convos::Core::User>

=back

=item * I<Convos::Controller>

=over 2

=item * L<Convos::Controller::Connection>

=item * L<Convos::Controller::Dialog>

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

=head2 extend_api_spec

  $self->extend_api_spec($path => \%spec);

Used to add more paths to the OpenAPI specification. This is useful
for plugins.

=head2 startup

This method sets up the application.

=head1 COPYRIGHT AND LICENSE

=head2 Material design icons

The icons used are provided by L<Google|https://www.google.com/design/icons>
under the L<CC-BY license|https://creativecommons.org/licenses/by/4.0/>.

=head2 Convos core and frontend

Copyright (C) 2012-2015, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

__DATA__
@@ layouts/convos.html.ep
% use Mojo::JSON 'to_json';
% my $description = "Convos is a chat application that runs in your web browser";
<!DOCTYPE html>
<html data-framework="vue">
  <head>
    <title><%= title %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="description" content="<%= $description %>">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:description" content="<%= $description %>">
    <meta name="twitter:image:src" content="https://convos.by/public/screenshots/2016-09-01-participants.png">
    <meta name="twitter:site" content="@convosby">
    <meta name="twitter:title" content="<%= title %>">
    <meta property="og:type" content="object">
    <meta property="og:description" content="<%= $description %>">
    <meta property="og:image" content="https://convos.by/public/screenshots/2016-09-01-participants.png">
    <meta property="og:site_name" content="<%= config 'organization_name' %>">
    <meta property="og:title" content="<%= title %>">
    <meta property="og:url" content="<%= $c->req->url->to_abs %>">
    <noscript><style>.if-js { display: none; }</style></noscript>
    %= asset 'favicon.ico'
    %= asset 'convos.css'
  </head>
  <body>
    %= content
    <div id="vue_tooltip"><span></span></div>
    %= javascript begin
      window.DEBUG = <%== to_json {map { ($_ => 1) } @$debug, split /,/, ($self->param('debug') || '')} %>;
      window.Convos = {
        apiUrl:   "<%= $c->url_for('api') %>",
        indexUrl: "<%= $c->url_for('index') %>",
        wsUrl:    "<%= $c->url_for('events')->to_abs->userinfo(undef)->to_string %>",
        mixin:    {}, // Vue.js mixins
        log:      [],
        mode:     "<%= app->mode %>",
        page:     "<%= stash('page') || '' %>",
        settings: <%== to_json app->config('settings') %>
      };
    % end
    %= asset 'convos.js';
    %= asset 'reloader.js' if app->mode eq 'development';
  </body>
</html>
@@ convos.html.ep
% layout 'convos';
% title config('organization_name') eq 'Convos' ? 'Convos - Better group chat' : 'Convos for ' . config('organization_name');
<component :is="user.currentPage" :current-page.sync="currentPage" :user="user">
  <div id="loader">
    <div class="row not-logged-in-wrapper">
      <div class="col s12 m6 offset-m3">
        <div class="row">
          <div class="col s12">
            <h1>Convos</h1>
            <p><i>- Collaboration done right.</i></p>
          </div>
        </div>
        <div class="row">
          <div class="col s12">
            <p class="if-js">Loading Convos should not take too long...</p>
            <noscript>
              <p>Javascript is disabled, so Convos will never load. Please enable Javascript and try again.</p>
            </noscript>
            <hr>
          </div>
        </div>
        <div class="row">
          <div class="col s12">
            <a href="" class="btn waves-effect waves-light">Reload</a>
          </div>
        </div>
        <div class="row">
          <div class="col s12 about">
          % if (config('organization_url') ne 'http://convos.by') {
            <a href="<%= config('organization_url') %>"><%= config('organization_name') %></a> -
          % }
            <a href="http://convos.by">About</a> -
            <a href="http://convos.by/doc">Documentation</a> -
            <a href="http://convos.by/blog">Blog</a>
          </div>
        </div>
      </div>
    </div>
  </div>
</component>
