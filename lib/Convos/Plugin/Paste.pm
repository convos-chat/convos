package Convos::Plugin::Paste;
use Mojo::Base 'Convos::Plugin';

use Convos::Plugin::Paste::File;
use Mojo::Date;

sub register {
  my ($self, $app, $config) = @_;
  $app->core->backend->on(multiline_message => 'Convos::Plugin::Paste::File');
  $app->routes->get('/paste/:user_id/:paste_id' => sub { $self->_serve(@_) });
}

sub _serve {
  my ($self, $c) = @_;
  my $user = $c->app->core->get_user_by_public_id($c->stash('user_id'));
  my $file = Convos::Plugin::Paste::File->new(id => $c->stash('paste_id'), user => $user);

  return $c->reply->not_found unless $file->user;
  return $c->app->core->backend->load_object_p($file)->then(sub {
    my $data = shift;
    return $c->reply->not_found unless $data->{created_at};
    $data->{created_at} = Mojo::Date->new($data->{created_at})->to_datetime;
    $c->render(paste => file => $data);
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Paste - Convos plugin to convert messages into paste

=head1 SYNOPSIS

  # enable
  $ CONVOS_PLUGINS=Convos::Plugin::Paste ./script/convos
  $ ./script/convos

  # disable
  $ CONVOS_PLUGINS= ./script/convos

=head1 DESCRIPTION

L<Convos::Plugin::Paste> is an EXPERIMENTAL paste plugin for L<Convos>.
It is enabled by default, but can be disabled by setting the C<CONVOS_PLUGINS>
environment variable to empty string.

The reasoning behind this plugin is that Convos should not "leak" data to an
external service by accident. If you however want to make something like a
L<https://gist.github.com/> plugin, then please have a look at the source code
of this plugin and/or come and talk to us at
L<irc://chat.freenode.net:6697/convos>.

=head1 METHODS

=head2 register

See L<Convos::Plugin/register>.

=head1 SEE ALSO

L<Convos>

=cut
