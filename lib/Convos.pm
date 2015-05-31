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
use Convos::Model;
use Swagger2::Editor;

our $VERSION = '0.01';

=head1 ATTRIBUTES

L<Convos> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 model

Holds a L<Convos::Model> object.

=cut

has model => sub { Convos::Model->new_with_backend($_[0]->config('backend')) };

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
  $self->plugin(Swagger2 => {url => $config->{swagger_file}});
  $self->routes->route('/spec')->detour(app => Swagger2::Editor->new(specification_file => $config->{swagger_file}));
  $self->routes->get('/')->to(template => 'app');
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
}

sub _config {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('Config') : $self->config;

  $config->{backend} ||= $ENV{CONVOS_BACKEND} || 'Convos::Model::Role::File';
  $config->{hypnotoad}{listen} ||= [split /,/, $ENV{MOJO_LISTEN} || 'http://*:8080'];
  $config->{hypnotoad}{pid_file} = $ENV{CONVOS_FRONTEND_PID_FILE} if $ENV{CONVOS_FRONTEND_PID_FILE};
  $config->{name} ||= $ENV{CONVOS_ORGANIZATION_NAME} || 'Nordaaker';
  $config->{swagger_file} ||= $self->home->rel_file('public/api.json');
  $config->{secure_cookies} ||= $ENV{CONVOS_SECURE_COOKIES} || 0;
  $config;
}

sub _home_relative_to_lib {
  my $self = shift;
  my $home = File::Spec->catdir(File::Basename::dirname(__FILE__), 'Convos');

  $self->home->parse($home);
  $self->static->paths->[0] = $self->home->rel_dir('public');
}

sub _setup_secrets {
  my $app = shift;
  my $secrets = $app->config('secrets') || [split /:/, $ENV{CONVOS_SECRETS} || ''];

  unless (@$secrets) {
    my $unsafe = join ':', $<, $(, $^X, qx{who -b 2>/dev/null}, $app->home;
    $app->log->warn('Using default (unsafe) session secrets. (Config file was not set up)');
    $secrets = [Mojo::Util::md5_sum($unsafe)];
  }

  $app->secrets($secrets);
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
</html>
