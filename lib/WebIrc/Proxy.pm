package WebIrc::Proxy;

use Mojo::Base -base;

has port => '6667';

sub start {
   my $self=shift;
   Mojo::IOLoop->server({ port => $self->port}, sub {
     ...
  });
}

1;
