package WebIrc::Core;

=head1 NAME

WebIrc::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use WebIrc::Core::Connection;
use constant DEBUG => $ENV{'WIRC_DEBUG'} // 1;

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has redis => sub { Mojo::Redis->new };
has _connections => sub { +{} };

=head1 METHODS

=head2 start

Will fetch connection information from the database and try to connect to them.

=cut

sub start {
  my $self = shift;

  $self->redis->smembers('connections', sub {
    my ($redis, $cids) = @_;
    warn sprintf "[core] Starting %s connection(s)\n", int @$cids if DEBUG;
    for my $cid (@$cids) {
      my $conn = WebIrc::Core::Connection->new(redis => $self->redis, id => $cid);
      $self->_connections->{$cid} = $conn;
      $conn->connect(sub {});
    }
  });
}

=head2 start_connection

Start a single connection by connection id.

=cut

sub start_connection {
  my ($self,$cid)=@_;
  return unless my $conn = $self->_connections->{$cid};
  return $conn->connect;
}

=head2 add_connection

    $self->add_connection($uid, {
      host => $str, # irc_server[:port]
      nick => $str,
      user => $str,
      channels => $str, # '#foo #bar ...'
    }, $callback);

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my ($self,$uid,$conn,$cb)=@_;
  my %errors;

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  return $self->$cb(undef, \%errors) if keys %errors;
  return $self->redis->incr('connections:id',sub {
    my ($redis,$cid) = @_;

    $self->_connections->{$cid} = WebIrc::Core::Connection->new(redis => $self->redis, id => $cid);
    $self->redis->execute(
      [ sadd => "connections", $cid ],
      [ sadd => "user:$uid:connections", $cid ],
      (
        map {
          [ sadd => "connection:$cid:channels", $_ ];
        } split /\s+/,delete $conn->{channels}
      ),
      (
        map {
          [ set => "connection:$cid:$_", $conn->{$_} ],
        } keys %$conn
      ),
      sub { $self->$cb($cid) },
    );
  });
}

=head2 login

  $self->login({ login => $str, password => $str }, $callback);

Will call callback after authenticating the user. C<$callback> will receive
either:

  $callback->($self, $uid); # success
  $callback->($self, undef, $error); # on error

=cut

sub login {
  my($self, $params, $cb)=@_;
  my $uid;

  Mojo::IOLoop->delay(
    sub {
      $self->redis->get('user:'.$params->{login}.':uid',$_[0]->begin);
    }, sub {
      my $delay = shift;
      $uid = shift;
      return $self->$cb($uid, shift) unless $uid && $uid =~ /\d+/;
      warn "[core] Got the uid: $uid" if DEBUG;
      $self->redis->get("user:$uid:digest", $delay->begin);
    }, sub {
      my($delay,$digest)=@_;
      if(crypt($params->{password},$digest) eq $digest) {
        warn "[core] User $uid has valid password" if DEBUG;
        $self->$cb($uid);
      }
      else {
        $self->$cb(undef, 'Could not verify digest');
      }
    }
  );
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
