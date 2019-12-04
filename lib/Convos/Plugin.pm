package Convos::Plugin;
use Mojo::Base 'Mojolicious::Plugin';

use Convos::Util 'DEBUG';
use Mojo::Util;

has uri => sub {
  my $self = shift;
  die "Cannot construct uri() from $self" unless ref($self) =~ /(\w+)$/;
  return Mojo::Path->new(sprintf '%s.json', Mojo::Util::decamelize($1));
};

sub add_backend_helpers {
  my ($self, $app) = @_;
  my $prefix = $self->uri->[0];

  $prefix =~ s!\.json$!!;
  $app->log->debug("Adding backend helpers \$c->$prefix->load() and \$c->$prefix->save()") if DEBUG;

  $app->helper("$prefix.load_p" => sub { shift->app->core->backend->load_object_p($self, @_) });
  $app->helper("$prefix.save_p" => sub { shift->app->core->backend->save_object_p($self, @_) });
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

=head2 uri

  $path = $self->uri;

Holds a L<Mojo::Path> object, with the URI to where this object should be
stored.

=head1 METHODS

=head2 add_backend_helpers

  $self->add_backend_helpers($app);

Can be used to add "load_p" and "save_p" helpers for the given plugin.

=head1 SEE ALSO

L<Convos> and L<Mojolicious::Plugin>.

=cut
