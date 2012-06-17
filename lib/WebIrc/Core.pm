package WebIrc::Core;

use Mojo::Base -base;

has 'redis';

sub start {
  my $self=shift;
  for my $conn ($self->connections) {
    $conn->connect()
  }
}

sub connections {
  my $self=shift;
  $self->redis->
}

1;