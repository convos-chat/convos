package WebIrc::Core;

=head1 NAME

WebIrc::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use WebIrc::Core::Connection;
use constant DEBUG => $ENV{WIRC_DEBUG} // 0;

=head1 ATTRIBUTES

=head2 log

Holds a L<Mojo::Log> object.

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has log => sub { Mojo::Log->new };

has redis => sub {
  my $self = shift;
  my $redis = Mojo::Redis->new(timeout => 0);
  my $log = $self->log;

  $redis->on(error => sub {
    my($redis, $error) = @_;
    $log->error("[CORE:REDIS] $error");
  });

  $redis;
};

=head1 METHODS

=head2 start

Will fetch connection information from the database and try to connect to them.

=cut

sub start {
  my $self = shift;

  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->smembers('connections', $delay->begin);
    },
    sub {
      my($delay, $cids) = @_;
      warn sprintf "[core] Starting %s connection(s)\n", int @$cids if DEBUG;
      $self->_connection(id => $_, $delay->begin) for @$cids;
    },
    sub {
      my($delay, @conn) = @_;
      $_->connect for @conn;
    }
  );

  $self->_start_control_channel;
  $self;
}

sub _connection {
  my $cb = pop;
  my($self, %args) = @_;
  my $conn = $self->{connections}{$args{id}};

  if($conn) {
    $self->$cb($conn);
  }
  elsif(!$args{uid}) {
    $self->redis->hget("connection:$args{id}", "uid", sub {
      my $uid = pop or die "Did you forget to run script/populate-connections-with-data.pl ?";
      $self->_connection(%args, uid => $uid, $cb);
    });
  }
  else {
    $conn = WebIrc::Core::Connection->new(redis => $self->redis, %args);
    $self->{connections}{$args{id}} = $conn;
    $self->$cb($conn);
  }
}

sub _start_control_channel {
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->{control} = $self->redis->subscribe('core:control');
  $self->{control}->timeout(0);
  $self->{control}->on(
    message => sub {
      my ($sub, $raw_msg) = @_;
      my ($command, $cid) = split /:/, $raw_msg;
      my $action = "ctrl_$command";
      $self->$action($cid);
    }
  );
  $self->{control}->on(
    error => sub {
      my ($sub, $error) = @_;
      $self->log->warn("[core:control] $error (reconnecting)");
      $self->_start_control_channel;
    },
  );
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
  my ($self, $uid, $conn, $cb) = @_;
  my %errors;

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  my $channels = delete $conn->{channels};
  my @channels = split m/[\s,]+/, $channels;

  $conn->{uid} = $uid;
  Scalar::Util::weaken($self);
  return $self->$cb(undef, \%errors) if keys %errors;
  return $self->redis->incr(
    'connections:id',
    sub {
      my ($redis, $cid) = @_;

      $self->_connection(id => $cid, uid => $uid, sub {});
      $self->redis->execute(
        [sadd  => "connections",              $cid],
        [sadd  => "user:$uid:connections",    $cid],
        [hmset => "connection:$cid",          %$conn],
        [sadd  => "connection:$cid:channels", @channels],
        sub { $self->$cb($cid) },
      );
    }
  );
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
  my ($self, $cid, $conn, $cb) = @_;
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
    [hmset => "connection:$cid", %$conn],
    [del   => "connection:$cid:channels"],
    [sadd  => "connection:$cid:channels", @channels],
    sub { $self->$cb($cid, {}); },
  );
}

=head2 ctrl_stop

    $self->ctrl_stop($cid);

Stop a connection by connection id.

=cut

sub ctrl_stop {
  my ($self, $cid) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$cid}) {
    $conn->disconnect(sub { delete $self->{connections}{$cid} });
  }
}

=head2 ctrl_restart

    $self->ctrl_restart($cid);

Restart a connection by connection id.

=cut


sub ctrl_restart {
  my ($self, $cid) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$cid}) {
    $conn->disconnect(sub {
      delete $self->{connections}{$cid};
      $self->ctrl_start($cid);
    });
  }
  else {
    $self->ctrl_start($cid);
  }
}

=head2 ctrl_start

Start a single connection by connection id.

=cut

sub ctrl_start {
  my ($self, $cid) = @_;

  $self->_connection(id => $cid, sub { pop->connect });
}

=head2 login

  $self->login({ login => $str, password => $str }, $callback);

Will call callback after authenticating the user. C<$callback> will receive
either:

  $callback->($self, $uid); # success
  $callback->($self, undef, $error); # on error

=cut

sub login {
  my ($self, $params, $cb) = @_;
  my $uid;

  Mojo::IOLoop->delay(
    sub {
      $self->redis->get("user:$params->{login}:uid", $_[0]->begin);
    },
    sub {
      my $delay = shift;
      $uid = shift;
      return $self->$cb($uid, shift) unless $uid && $uid =~ /\d+/;
      warn "[core] Got the uid: $uid" if DEBUG;
      $self->redis->hget("user:$uid", "digest", $delay->begin);
    },
    sub {
      my ($delay, $digest) = @_;
      if (crypt($params->{password}, $digest) eq $digest) {
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
