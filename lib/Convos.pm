package Convos;

=head1 NAME

Convos - Multiuser chat application

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Convos> is a multiuser chat application built with L<Mojolicious>.

It currently support the IRC protocol, but can be extended to support
other protocols as well.

=head1 SYNOPSIS

You can start convos by running one of the commands below.

  $ convos daemon;
  $ convos daemon --listen http://*:3000;

You can then visit Convos in your browser, by going to the default
address L<http://localhost:3000>.

=head1 SEE ALSO

=over 4

=item * L<Convos::Manual::API>

=back

=cut

use Mojo::Base 'Mojolicious';
use Convos::Core;
use Swagger2::Editor;

our $VERSION = '0.01';

=head1 ATTRIBUTES

L<Convos> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 core 

Holds a L<Convos::Core> object.

=cut

has core => sub {
  my $self    = shift;
  my $backend = $self->config('backend');
  eval "require $backend;1" or die $@;
  Convos::Core->new(backend => $backend->new);
};

=head1 METHODS

L<Convos> inherits all methods from L<Mojolicious> and implements
the following new ones.

=head2 startup

This method set up the application.

=cut

sub startup {
  my $self   = shift;
  my $config = $self->_config;

  $self->_home_relative_to_lib unless -d $self->home->rel_dir('public');
  $self->_setup_secrets;
  $self->_add_helpers;
  $self->_setup_assets;
  $self->plugin(Swagger2 => {url => $config->{swagger_file}});
  $self->routes->route('/spec')->detour(app => Swagger2::Editor->new(specification_file => $config->{swagger_file}));
  $self->routes->get('/')->to(template => 'app');
  $self->sessions->cookie_name('convos');
  $self->sessions->default_expiration(86400 * 30);
  $self->sessions->secure(1) if $config->{secure_cookies};
  push @{$self->renderer->classes}, __PACKAGE__;

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      my $base = $c->req->headers->header('X-Request-Base') or return;
      $c->req->url->base(Mojo::URL->new($base));
    }
  );

  my $core    = $self->core;
  my $plugins = $config->{plugins};
  $core->backend->register_plugin($_, $core, $plugins->{$_}) for grep { $plugins->{$_} } keys %$plugins;
  $core->start if $ENV{CONVOS_START_BACKEND} // 1;
}

sub _add_helpers {
  my $self = shift;

  $self->helper(
    invalid_request => sub {
      my ($c, $message, $path) = @_;
      my @errors;

      if (UNIVERSAL::isa($message, 'Mojolicious::Validator::Validation')) {
        $path ||= '';
        push @errors, map {
          my $error = $message->error($_);
          {message => $error->[0] eq 'required' ? 'Missing property.' : 'Invalid input.', path => "$path/$_"}
        } sort keys %{$message->{error}};
      }
      else {
        push @errors, {message => $message, path => $path || '/'};
      }

      return {valid => Mojo::JSON->false, errors => \@errors};
    }
  );

  $self->helper(
    'backend.user' => sub {
      my $self = shift;
      return undef unless $self->session('email');
      return $self->app->core->user($self->session('email'));
    }
  );

  $self->helper(
    unauthorized => sub {
      my ($self, $cb) = @_;
      $self->$cb($self->invalid_request('Need to log in first.', '/X-Convos-Session'), 401);
    }
  );
}

sub _config {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : $self->config;

  $config->{backend} ||= $ENV{CONVOS_BACKEND} || 'Convos::Core::Backend::File';
  $config->{hypnotoad}{listen} ||= [split /,/, $ENV{MOJO_LISTEN} || 'http://*:8080'];
  $config->{hypnotoad}{pid_file} = $ENV{CONVOS_FRONTEND_PID_FILE} if $ENV{CONVOS_FRONTEND_PID_FILE};
  $config->{name} ||= $ENV{CONVOS_ORGANIZATION_NAME} || 'Nordaaker';
  $config->{plugins} ||= {};
  $config->{plugins}{$_} = $config for split /:/, +($ENV{CONVOS_PLUGINS} // '');
  $config->{secure_cookies} ||= $ENV{CONVOS_SECURE_COOKIES} || 0;
  $config->{swagger_file} ||= $self->home->rel_file('public/api.json');
  $config;
}

sub _home_relative_to_lib {
  my $self = shift;
  my $home = File::Spec->catdir(File::Basename::dirname(__FILE__), 'Convos');

  $self->home->parse($home);
  $self->static->paths->[0] = $self->home->rel_dir('public');
}

sub _setup_assets {
  my $self       = shift;
  my @javascript = qw(
    http://code.jquery.com/jquery-1.11.3.min.js
    http://cdnjs.cloudflare.com/ajax/libs/riot/2.1.0/riot.js
    /js/storage.js
    /js/window.js
    /js/router.js
    /js/jquery.autocomplete.js
    /js/jquery.disableouterscroll.js
    /js/materialize/hammer.min.js
    /js/materialize/jquery.hammer.js
    /js/materialize/velocity.min.js
    /js/materialize/waves.js
    /js/materialize/jquery.easing.1.3.js
    /js/materialize/jquery.timeago.min.js
    /js/materialize/global.js
    /js/materialize/animation.js
    /js/materialize/buttons.js
    /js/materialize/dropdown.js
    /js/materialize/forms.js
    /js/materialize/leanModal.js
    /js/materialize/tooltip.js
    /js/materialize/animation.js
    /js/mixins/base.js
    /js/mixins/form.js
    /js/mixins/http.js
    /js/mixins/modal.js
    /js/core/connection.js
    /js/core/conversation-room.js
    /js/core/conversation-direct.js
    /js/core/user.js
  );

  push @javascript, map {"/js/riot/$_"} sort { $a cmp $b } @{$self->home->list_files('public/js/riot')};

  $self->plugin('riotjs');
  $self->asset('convos.css' => 'sass/main.scss');
  $self->asset('convos.js' => @javascript, '/js/main.js');
}

sub _setup_secrets {
  my $self = shift;
  my $secrets = $self->config('secrets') || [split /:/, $ENV{CONVOS_SECRETS} || ''];

  unless (@$secrets) {
    my $unsafe = join ':', $<, $(, $^X, qx{who -b 2>/dev/null}, $self->home;
    $self->log->warn('Using default (unsafe) session secrets. (Config file was not set up)');
    $secrets = [Mojo::Util::md5_sum($unsafe)];
  }

  $self->secrets($secrets);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

__DATA__
@@ app.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>Convos</title>
    %= asset 'convos.css';
    %= javascript begin
      window.Convos = {};
      window.apiUrl = function(path){return ['<%= $self->url_for('/1.0')->to_abs->userinfo(undef)->path %>'].concat(path).join('/').replace(/\/+/g, '/').replace(/#/g, '%23')};
      window.urlFor = function(path){return ['<%= $self->url_for('/')->to_abs->userinfo(undef)->path %>'].concat(path).join('/').replace(/\/+/g, '/').replace(/#/g, '%23')};
    % end
  </head>
  <body>
    <div class="loading-convos valign-wrapper">
      <div class="valign center">
        <h5>Loading <a href="https://convos.by">Convos</a>...</h5>
        <p class="grey-text">This should only take a few seconds.</p>
      </div>
    </div>
    <div id="app"></div>
    <div id="modal_bottom_sheet" class="modal bottom-sheet"></div>
    %= asset 'convos.js';
  </body>
</html>
