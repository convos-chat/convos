package WebIrc::Client;

use Mojo::Base 'Mojolicious::Controller';

sub view {
  my $self=shift;
  $self->stash( servers => );
}

1;