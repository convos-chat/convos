package Convos::Plugin;
use Mojo::Base 'Mojolicious::Plugin';

use Convos::Util 'DEBUG';
use Mojo::Util 'decamelize';

has id => sub { ref($_[0]) =~ /(\w+)$/ ? $1 : 'convos_plugin' };

sub add_backend_helpers {
  my ($self, $app) = @_;
  my $prefix = decamelize $self->id;

  $app->log->debug("Adding backend helpers \$c->$prefix->load() and \$c->$prefix->save()") if DEBUG;

  $app->helper(
    "$prefix.load" => sub {
      shift->app->core->backend->load_object($self, @_);
    }
  );

  $app->helper(
    "$prefix.save" => sub {
      shift->app->core->backend->save_object($self, @_);
    }
  );
}

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

=head1 ATTRIBUTES

=head2 id

  $self = $self->id("MyPlugin");
  $str = $self->id;

An identifier for this plugin. Used as prefix for helpers and for debug
purposes.

=head1 METHODS

=head2 add_backend_helpers

  $self->add_backend_helpers($app);

Can be used to add "load" and "save" helpers for the given plugin.

=head1 SEE ALSO

L<Convos> and L<Mojolicious::Plugin>.

=cut
