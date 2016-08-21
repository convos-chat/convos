package Convos;
use Mojo::Base 'Mojolicious';

use Convos::Core;
use Convos::Util;
use Mojo::JSON qw(false true);

our $VERSION = '0.01';

has core => sub {
  my $self    = shift;
  my $backend = $self->config('backend');
  eval "require $backend;1" or die $@;
  Convos::Core->new(backend => $backend->new);
};

has _link_cache => sub { Mojo::Cache->new->max_keys($ENV{CONVOS_MAX_LINK_CACHE_SIZE} || 100) };

sub startup {
  my $self   = shift;
  my $config = $self->_config;
  my $r      = $self->routes;

  $self->_home_relative_to_lib unless -d $self->home->rel_dir('public');
  $self->_setup_secrets;
  $self->_add_helpers;
  $self->routes->namespaces(['Convos::Controller']);
  $self->sessions->cookie_name('convos');
  $self->sessions->default_expiration(86400 * 7);
  $self->sessions->secure(1) if $config->{secure_cookies};
  push @{$self->renderer->classes}, __PACKAGE__;

  # Add basic routes
  $r->get('/')->to(template => 'convos')->name('index');
  $r->websocket('/events')->to('events#start')->name('events');

  # Autogenerate routes from the OpenAPI specification
  $self->plugin(OpenAPI => {url => $self->static->file('convos-api.json')->path});

  # Expand links into rich content
  $self->plugin('LinkEmbedder');

  # Add /perldoc route for documentation
  $self->plugin('PODRenderer')->to(module => 'Convos');

  $self->plugin(AssetPack => {pipes => [qw(Vuejs JavaScript Sass Css Combine Reloader)]});
  $self->asset->process;

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      my $base = $c->req->headers->header('X-Request-Base') or return;
      $c->req->url->base(Mojo::URL->new($base));
    }
  );

  my $core    = $self->core;
  my $plugins = $config->{plugins};
  $core->backend->register_plugin($_, $core, $plugins->{$_})
    for grep { $plugins->{$_} } keys %$plugins;
  $core->start if $ENV{CONVOS_START_BACKEND} // 1;
}

sub _add_helpers {
  my $self = shift;

  $self->helper(
    'backend.user' => sub {
      my $self = shift;
      return undef unless my $email = $self->session('email');
      return $self->app->core->get_user({email => $email});
    }
  );

  $self->helper(
    settings => sub {
      my $config = shift->app->config;
      return {
        contact           => $config->{contact},
        default_server    => $config->{default_server},
        forced_irc_server => $config->{forced_irc_server} ? true : false,
        invite_code       => $config->{invite_code} ? true : false,
        organization_name => $config->{organization_name},
      };
    }
  );

  $self->helper(
    unauthorized => sub {
      shift->render(openapi => Convos::Util::E('Need to log in first.'), status => 401);
    }
  );
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
  $config->{plugins} ||= {};
  $config->{plugins}{$_} = $config for split /,/, +($ENV{CONVOS_PLUGINS} // '');
  $config->{secure_cookies} ||= $ENV{CONVOS_SECURE_COOKIES} || 0;
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

0.01

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

=head2 startup

This method sets up the application.

=head1 COPYRIGHT AND LICENSE

=head2 Material design icons

The icons used are provided by L<Google|https://www.google.com/design/icons>
under the L<CC-BY license|https://creativecommons.org/licenses/by/4.0/>.

=head2 Robot images

Robots lovingly delivered by L<https://robohash.org> under the
L<CC-BY license|https://creativecommons.org/licenses/by/4.0/>.

=head2 Convos core and frontend

Copyright (C) 2012-2015, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

__DATA__
@@ convos.html.ep
<!DOCTYPE html>
<html data-framework="vue">
  <head>
    <title>Convos</title>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    %= asset 'convos.css';
  </head>
  <body>
    <div id="loader" class="centered">
      <div>
        <h4>Loading convos...</h4>
        <p class="error">This should not take too long.</p>
        <a href="">Reload <i class="material-icons">refresh</i></a>
      </div>
    </div>
    <component :is="user.currentPage" :current-page.sync="currentPage" :user="user"></component>
    <div id="vue_tooltip"><span></span></div>
    %= javascript begin
      window.Convos = {
        apiUrl:   "<%= $c->url_for('api') %>",
        indexUrl: "<%= $c->url_for('index') %>",
        wsUrl:    "<%= $c->url_for('events')->to_abs->userinfo(undef)->to_string %>",
        mode:     "<%= app->mode %>",
        settings: <%== Mojo::JSON::encode_json(settings) %>,
        mixin:    {} // Vue.js mixins
      };
    % end
    %= asset 'convos.js';
  </body>
</html>
