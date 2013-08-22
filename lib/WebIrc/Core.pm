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

=head2 control

  $self->control($command, $cb);

Used to issue a control command.

=cut

sub control {
  my($self, @args) = @_;
  my $cb = pop @args;

  $self->redis->lpush('core:control', join(':', @args), $cb);
  $self;
}

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
      my($delay, $connections) = @_;
      warn sprintf "[core] Starting %s connection(s)\n", int @$connections if DEBUG;
      for(@$connections) {
        my($uid, $host) = split /:/;
        $self->_connection(uid => $uid, host => $host, $delay->begin)
      }
    },
    sub {
      my($delay, @conn) = @_;
      $_->connect for @conn;
    },
  );

  $self->_start_control_channel;
  $self;
}

sub _connection {
  my $cb = pop;
  my($self, %args) = @_;
  my $conn = $self->{connections}{$args{uid}}{$args{host}};

  if($conn) {
    $self->$cb($conn);
  }
  else {
    $conn = WebIrc::Core::Connection->new(redis => $self->redis, %args);
    $self->{connections}{$args{uid}}{$args{host}} = $conn;
    $self->$cb($conn);
  }
}

sub _start_control_channel {
  my $self = shift;
  my $cb;

  Scalar::Util::weaken($self);

  $cb = sub {
    my($redis, $name, $li) = @_;
    $redis->brpop($name => 0, $cb);
    $li or return;
    my($command, $uid, $host) = split /:/, $li->[1];
    my $action = "ctrl_$command";
    $self->$action($uid, $host);
  };

  $self->{control} = Mojo::Redis->new(timeout => 0, server => $self->redis->server);
  $self->{control}->$cb('core:control');
  $self->{control}->on(
    error => sub {
      my($redis, $error) = @_;
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
  my ($key, @channels, %errors);

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  @channels = $self->_parse_channels($conn->{channels});
  @channels or $errors{channels} = "channels is required.";
  $key = join ':', "user:$uid:connection:$conn->{host}";
  $conn->{channels} = join ' ', @channels;
  warn "[core:uid:$uid] add (", join(', ', %$conn), ")\n" if DEBUG;

  Scalar::Util::weaken($self);
  return $self->$cb(\%errors, undef) if keys %errors;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->exists($key, $delay->begin);
    },
    sub {
      my($delay, $exists) = @_;

      return $self->$cb({ host => 'Connection exists' }, undef) if $exists;
      return $self->redis->execute(
        [sadd => "connections", "$uid:$conn->{host}"],
        [sadd => "user:$uid:connections", $conn->{host}],
        [hmset => "user:$uid:connection:$conn->{host}", %$conn],
        $delay->begin,
      );
    },
    sub {
      my($delay, @saved) = @_;
      $self->control(start => $uid => $conn->{host}, $delay->begin);
    },
    sub {
      my($delay, $started) = @_;
      $self->$cb(undef, $conn);
    },
  );
}

=head2 update_connection

  $self->update_connection($uid => {
    host => $str, # irc_server[:port]
    lookup => $str, # irc_server[:port]
    nick => $str,
    user => $str,
    channels => $str, # '#foo #bar, ...'
  }, $callback);

Update a connection's settings and reconnect.

=cut

sub update_connection {
  my ($self, $uid, $conn, $cb) = @_;
  my $lookup = delete $conn->{lookup};
  my (%errors, @channels, %channels);

  Scalar::Util::weaken($self);

  if($conn->{host} ne $lookup) {
    warn "[core:uid:$uid] update $lookup -> add/delete\n";
    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $self->add_connection($uid => $conn, $delay->begin);
      },
      sub {
        my($delay, $error, $res) = @_;
        return $self->$cb($error, undef) if $error;
        return $self->delete_connection($uid => $lookup, $delay->begin);
      },
      sub {
        my($delay, $error) = @_;
        # TODO: How to handle error?
        return $self->$cb('', $conn);
      },
    );
    return $self;
  }

  for my $name (qw/ host nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  return $self->$cb(\%errors, undef) if keys %errors;
  warn "[core:uid:$uid] update (", join(', ', %$conn), ")\n" if DEBUG;
  @channels = $self->_parse_channels($conn->{channels});
  $conn->{channels} = join ' ', @channels;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hgetall("user:$uid:connection:$conn->{host}", $delay->begin);
    },
    sub {
      my($delay, $found) = @_;

      return $self->$cb('Connection does not exist', undef) unless $found;
      %channels = map { $_, 1 } split ' ', $found->{channels};
      delete $found->{host}; # want this value
      $conn->{$_} ~~ $found->{$_} and delete $conn->{$_} for keys %$found;

      if(%$conn) {
        $self->redis->hmset("user:$uid:connection:$conn->{host}", %$conn, $delay->begin)
      }
      if($conn->{nick}) {
        $self->redis->publish("wirc:user:$uid:in", "NICK $conn->{nick}", $delay->begin);
        warn "[core:uid:$uid] NICK $conn->{nick}\n" if DEBUG;
      }
      for my $channel (@channels) {
        next if delete $channels{$channel};
        $self->redis->publish("wirc:user:$uid:in", "JOIN $channel", $delay->begin);
        warn "[core:uid:$uid] JOIN $_\n" if DEBUG;
      }
      for my $channel (keys %channels) {
        $self->redis->publish("wirc:user:$uid:in", "PART $channel", $delay->begin);
        warn "[core:uid:$uid] PART $channel\n" if DEBUG;
      }

      $delay->begin->();
    },
    sub {
      my($delay, @saved) = @_;
      $self->$cb('', $conn);
    },
  );
}

=head2 delete_connection

  $self->delete_connection($uid, $host, $cb);

=cut

sub delete_connection {
  my($self, $uid, $host, $cb) = @_;

  warn "[core:uid:$uid] delete $host\n" if DEBUG;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->srem("connections", "$uid:$host", $delay->begin);
      $self->redis->srem("user:$uid:connections", $host, $delay->begin);
    },
    sub {
      my ($delay, @removed) = @_;
      return $self->$cb('Unknown connection') unless grep $_, @removed;
      $self->redis->keys("user:$uid:connection:$host:*", $delay->begin); # jht: not sure if i like this...
      $self->redis->zrange("user:$uid:conversations", 0, -1, $delay->begin);
    },
    sub {
      my ($delay, $keys, $conversations) = @_;
      $self->redis->del(@$keys, $delay->begin);
      $self->redis->zrem("user:$uid:conversations", $_) for grep { /^$host:/ } @$conversations;
      $self->control(stop => $uid => $host, $delay->begin);
    },
    sub {
      my($delay, @deleted) = @_;
      $self->$cb('');
    },
  );
}

=head2 ctrl_stop

    $self->ctrl_stop($uid, $host);

Stop a connection by connection id.

=cut

sub ctrl_stop {
  my ($self, $uid, $host) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$uid}{$host}) {
    $conn->disconnect(sub { delete $self->{connections}{$uid}{$host} });
  }
}

=head2 ctrl_restart

    $self->ctrl_restart($uid, $host);

Restart a connection by connection id.

=cut


sub ctrl_restart {
  my ($self, $uid, $host) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$uid}{$host}) {
    $conn->disconnect(sub {
      delete $self->{connections}{$uid}{$host};
      $self->ctrl_start($uid => $host);
    });
  }
  else {
    $self->ctrl_start($uid => $host);
  }
}

=head2 ctrl_start

Start a single connection by connection id.

=cut

sub ctrl_start {
  my ($self, $uid, $host) = @_;

  $self->_connection(name => $uid => $host, sub { pop->connect });
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
      warn "[core:uid:$uid] login\n" if DEBUG;
      $self->redis->hget("user:$uid", "digest", $delay->begin);
    },
    sub {
      my ($delay, $digest) = @_;
      if (crypt($params->{password}, $digest) eq $digest) {
        warn "[core:uid:$uid] Valid password\n" if DEBUG;
        $self->$cb($uid);
      }
      else {
        $self->$cb(undef, 'Could not verify digest');
      }
    }
  );
}

sub _parse_channels {
  my $self = shift;
  my $channels = shift or return;
  sort grep { $_ ne '#' } map { /^#/ ? $_ : "#$_" } split m/[\s,]+/, $channels;
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
