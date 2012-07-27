package WebIrc::Core;

use Mojo::Base -base;

use WebIrc::Core::Connection;

has 'redis';

sub start {
  my $self = shift;
  $self->redis->del('connections:connected');
  $self->connections(sub {
    for my $conn (@_) {
      $conn->connect;
    }
  })
}

sub connections {
  my ($self,$cb) = @_;
  $self->redis->smembers('connections',
    sub {
      my ($redis, $res) = @_;
      my @connections = map {
        my $conn = WebIrc::Core::Connection->new(redis => $self->redis);
        #
        $conn->load($_);
      } @$res;
      $cb->(@connections);
  });
}

sub login {
  my ($self,@cred)=@_;
}

sub register {
  my ($self,%user)=@_;
}

1;