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

=head1 METHODS

=head2 start

TODO

=cut

sub start {
  my $self = shift;
  $self->redis->del('connections:connected');
  $self->connections(sub {
    for my $conn (@_) {
      $conn->connect;
    }
  })
}

=head2 connections

TODO

=cut

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
