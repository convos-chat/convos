package WebIrc::Core;

=head1 NAME

WebIrc::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;

use WebIrc::Core::Connection;

=head1 ATTRIBUTES

=head2 redis

TODO

=cut

has 'redis';


=head2 connections

List of Connections, defaults to being fetched from Redis

=cut

has connections => sub {
  my ($self,$cb) = @_;
  $self->redis->smembers('connections',
    sub {
      my ($redis, $res) = @_;
      $cb->(map {
        WebIrc::Core::Connection->new(redis => $self->redis,id=>$_);
      } @$res);
   });
}


=head1 METHODS

=head2 start

TODO

=cut

sub start {
  my $self = shift;
  $self->redis->del('connections:connected');
  $self->connections(sub {
    warn sprintf "[core] Starting %s connection(s)\n", int @_ if WebIrc::Core::Connection::DEBUG;
    for my $conn (@_) {
      $conn->connect;
    }
  })
}



=head2 add_connection %conn

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my ($self,$uid,%conn)=@_;
  $self->redis->incr('connnections:id',sub {
    my ($redis,$res)=@_;
    $self->redis->sadd('connections',$res);
    for my $key (keys %conn) {
      $self->redis->set('connection:'.$res.':'.$conn{$key});
    }
  });
}



=head2 login

TODO

=cut

sub login {
  my ($self,@cred)=@_;
}

=head2 register

TODO

=cut

sub register {
  my ($self,%user)=@_;
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
