package WebIrc::Core;

=head1 NAME

WebIrc::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use WebIrc::Core::Connection;
use constant DEBUG => $ENV{WIRC_DEBUG} // 1;

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

  Scalar::Util::weaken($self);
  $self->redis->smembers('connections', sub {
    my ($redis, $cids) = @_;
    return unless $cids and @$cids;
    warn sprintf "[core] Starting %s connection(s)\n", int @$cids if DEBUG;
    for my $cid (@$cids) {
      my $conn = WebIrc::Core::Connection->new(redis => $self->redis, id => $cid);
      $self->_connections->{$cid} = $conn;
      $conn->connect(sub {});
    }
  });
  $self->{control} = $self->redis->subscribe("core:control");
  $self->{control}->on(message => sub {
    my ($sub, $raw_msg)=@_;
    my ($msg,$cid)=split(':',$raw_msg);
    my $action = 'ctrl_'. $msg;
    $self->$action($cid) if $self->can($action);
  });
  
}



=head2 add_connection

    $self->add_connection($uid, {
      host => $str, # irc_server[:port]
      nick => $str,
      user => $str,
      channels => $str, # '#foo #bar, ...'
    }, $callback);

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my ($self,$uid,$conn,$cb) = @_;
  my %errors;

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  my $channels = delete $conn->{channels};
  my @channels = split m/[\s,]+/, $channels;

  Scalar::Util::weaken($self);
  return $self->$cb(undef, \%errors) if keys %errors;
  return $self->redis->incr('connections:id',sub {
    my ($redis,$cid) = @_;

    $self->_connections->{$cid} = WebIrc::Core::Connection->new(redis => $self->redis, id => $cid);
    $self->redis->execute(
      [ sadd => "connections", $cid ],
      [ sadd => "user:$uid:connections", $cid ],
      [ hmset => "connection:$cid", %$conn ],
      [ sadd=> "connection:$cid:channels", @channels ],
      sub { $self->$cb($cid) },
    );
  });
}

=head2 update_connection

    $self->update_connection($cid, {
      host => $str, # irc_server[:port]
      nick => $str,
      user => $str,
      channels => $str, # '#foo #bar, ...'
    }, $callback);

Update a connection's settings and reconnect.

=cut

sub update_connection {
  my ($self,$cid,$conn,$cb)=@_;
  my (%errors, @channels, $channels, $connections);

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  Scalar::Util::weaken($self);
  $channels = delete $conn->{channels};
  @channels = split m/[\s,]+/, $channels;

  return $self->$cb(undef, \%errors) if keys %errors;
  return $self->redis->execute(
    [ hmset => "connection:$cid", %$conn ],
    [ del   => "connection:$cid:channels"],
    [ sadd  => "connection:$cid:channels", @channels],
    sub {
      $self->redis->publish('core:control',"restart:$cid");
      $self->$cb($cid) ;
    },
  );
}

=head2 ctrl_stop

    $self->ctrl_stop($cid);

Stop a connection by connection id.

=cut

sub ctrl_stop {
  my ($self,$cid)=@_;

  Scalar::Util::weaken($self);
  $self->_connections->{$cid}->disconnect(sub {
    delete $self->_connections->{$cid};
  });
}

=head2 ctrl_restart

    $self->ctrl_restart($cid);

Restart a connection by connection id.

=cut


sub ctrl_restart {
  my ($self,$cid)=@_;
  # flush
  Scalar::Util::weaken($self);
  if($self->_connections->{$cid}) {
    $self->_connections->{$cid}->disconnect(sub { $self->ctrl_start($cid) });
  }
  else {
    $self->ctrl_start($cid);
  }
}

=head2 ctrl_start

Start a single connection by connection id.

=cut

sub ctrl_start {
  my ($self,$cid) = @_;
  my $conn = $self->_connections->{$cid} ||= WebIrc::Core::Connection->new(redis => $self->redis, id => $cid);
  $conn->connect(sub {});
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
      $self->redis->get("user:$params->{login}:uid",$_[0]->begin);
    }, sub {
      my $delay = shift;
      $uid = shift;
      return $self->$cb($uid, shift) unless $uid && $uid =~ /\d+/;
      warn "[core] Got the uid: $uid" if DEBUG;
      $self->redis->hget("user:$uid", "digest", $delay->begin);
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
