package Convos::Plugin;
use Mojo::Base 'Mojolicious::Plugin';

1;

=encoding utf8

=head1 NAME

Convos::Plugin - Base class for Convos plugins

=head1 SYNOPSIS

  package Convos::Plugin::CoolPlugin;
  use Mojo::Base "Convos::Plugin";

  sub register {
    my ($self, $app, $config) = @_;

    $app->core->backend->on(connection => sub {
      my ($backend, $connection) = @_;
      warn "New connection!";
    });
  }

=head1 DESCRIPTION

L<Convos::Plugin> is the base class for Convos plugins, which all plugins need
to inherit from.

=head1 SEE ALSO

L<Convos> and L<Mojolicious::Plugin>.

=cut
