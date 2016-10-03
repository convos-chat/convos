package Convos;
use Mojo::Base 'Mojolicious';

use Convos::Core;
use Convos::Util;
use Mojo::JSON qw(false true);
use Mojo::Util;

our $VERSION = '0.99_12';

has core => sub { Convos::Core->new(backend => shift->config('backend')) };

has _api_spec => sub {
  my $self = shift;
  my $path = $self->static->file('convos-api.json')->path;
  return Mojo::JSON::decode_json(Mojo::Util::slurp($path));
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

  $self->_home_relative_to_lib unless -d $self->home->rel_dir('public');
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
  $self->_assets;

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      my $base = $c->req->headers->header('X-Request-Base') or return;
      $c->req->url->base(Mojo::URL->new($base));
    }
  );

  $self->core->start if $ENV{CONVOS_START_BACKEND} // 1;
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
  my $custom_assets = $self->core->home->rel_dir('assets');

  $self->plugin(AssetPack => {pipes => [qw(Favicon Vuejs JavaScript Sass Css Combine)]});

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
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : $self->config;

  $config->{backend}           ||= $ENV{CONVOS_BACKEND}           || 'Convos::Core::Backend::File';
  $config->{contact}           ||= $ENV{CONVOS_CONTACT}           || 'mailto:root@localhost';
  $config->{forced_irc_server} ||= $ENV{CONVOS_FORCED_IRC_SERVER} || '';
  $config->{default_server}
    ||= $config->{forced_irc_server} || $ENV{CONVOS_DEFAULT_SERVER} || 'localhost';
  $config->{invite_code} ||= $ENV{CONVOS_INVITE_CODE} // $self->_generate_invite_code;
  $config->{organization_name} ||= $ENV{CONVOS_ORGANIZATION_NAME} || 'Nordaaker';
  $config->{secure_cookies}    ||= $ENV{CONVOS_SECURE_COOKIES}    || 0;

  # public settings
  $config->{settings} = {
    contact           => $config->{contact},
    default_server    => $config->{default_server},
    forced_irc_server => $config->{forced_irc_server} ? true : false,
    invite_code       => $config->{invite_code} ? true : false,
    organization_name => $config->{organization_name},
  };

  $config;
}

sub _generate_invite_code {
  my $self = shift;
  my $code = Mojo::Util::md5_sum(join ':', $<, $(, $^X, $0);
  $self->log->info(qq(Generated CONVOS_INVITE_CODE="$code"));
  return $code;
}

sub _home_relative_to_lib {
  my $self = shift;
  my $home = File::Spec->catdir(File::Basename::dirname(__FILE__), 'Convos');

  $self->home->parse($home);
  $self->static->paths->[0] = $self->home->rel_dir('public');
}

sub _plugins {
  my $self    = shift;
  my $plugins = $self->config('plugins');

  unshift @{$self->plugins->namespaces}, 'Convos::Plugin';

  $ENV{CONVOS_PLUGINS} //= '';
  $plugins ||= {};
  $plugins->{'Convos::Plugin::Helpers'} = {};    # core plugin
  $plugins->{$_} = {} for split /,/, $ENV{CONVOS_PLUGINS};
  $self->plugin($_ => $plugins->{$_}) for grep { $plugins->{$_} } keys %$plugins;
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

0.99_12

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
<!DOCTYPE html>
<html data-framework="vue">
  <head>
    <title><%= title %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    %= asset 'favicon.ico'
    %= asset 'convos.css'
  </head>
  <body>
    %= content
    <div id="vue_tooltip"><span></span></div>
    %= javascript begin
      window.Convos = {
        apiUrl:   "<%= $c->url_for('api') %>",
        indexUrl: "<%= $c->url_for('index') %>",
        wsUrl:    "<%= $c->url_for('events')->to_abs->userinfo(undef)->to_string %>",
        mixin:    {}, // Vue.js mixins
        mode:     "<%= app->mode %>",
        page:     "<%= stash('page') || '' %>",
        settings: <%== Mojo::JSON::to_json(app->config('settings')) %>
      };
    % end
    %= asset 'convos.js';
  </body>
</html>
@@ convos.html.ep
% layout 'convos';
% title 'Convos for ' . config('organization_name');
<component :is="user.currentPage" :current-page.sync="currentPage" :user="user">
  <div id="loader" class="centered">
    <div>
      <h4>Loading convos...</h4>
      <p class="error">This should not take too long.</p>
      <a href="">Reload <i class="material-icons">refresh</i></a>
    </div>
  </div>
</component>
