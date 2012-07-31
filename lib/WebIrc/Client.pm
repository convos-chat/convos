package WebIrc::Client;

use Mojo::Base 'Mojolicious::Controller';

sub view {
  my $self = shift;

  $self->stash(is_channel => $self->param('target') =~ /^#/ ? 1 : 0);
}

1;
