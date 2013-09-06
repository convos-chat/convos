package WebIrc::Core;

=head1 NAME

WebIrc::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use WebIrc::Core::Connection;
use WebIrc::Core::Util qw/ as_id id_as /;
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
  my $redis = Mojo::Redis->new;
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
      $self->redis->del('wirc:loopback:names'); # clear loopback nick list
      $self->redis->smembers('connections', $delay->begin);
    },
    sub {
      my($delay, $connections) = @_;
      warn sprintf "[core] Starting %s connection(s)\n", int @$connections if DEBUG;
      for my $conn (@$connections) {
        my($login, $server) = split /:/, $conn;
        $self->_connection(login => $login, server => $server)->connect;
      }
    },
  );

  $self->_start_control_channel;
  $self;
}

sub _connection {
  my($self, %args) = @_;
  my $conn = $self->{connections}{$args{login}}{$args{server}};

  unless($conn) {
    $conn = WebIrc::Core::Connection->new(redis => $self->redis, %args);
    $self->{connections}{$args{login}}{$args{server}} = $conn;
  }

  $conn;
}

sub _start_control_channel {
  my $self = shift;
  my $cb;

  Scalar::Util::weaken($self);

  $cb = sub {
    my($redis, $li) = @_;
    $redis->brpop($li->[0], 0, $cb);
    $li->[1] or return;
    my($command, $login, $server) = split /:/, $li->[1];
    my $action = "ctrl_$command";
    $self->$action($login, $server);
  };

  $self->{control} = Mojo::Redis->new(server => $self->redis->server);
  $self->{control}->$cb(['core:control']);
  $self->{control}->on(
    error => sub {
      my($redis, $error) = @_;
      $self->log->warn("[core:control] $error (reconnecting)");
      Mojo::IOLoop->timer(0.5, sub { $self->_start_control_channel })
    },
  );
}

=head2 add_connection

  $self->add_connection($login, {
    server => $str, # irc_server[:port]
    nick => $str,
    user => $str,
    channels => [ '#foo', '#bar', '...' ],
    tls => $bool,
  }, $callback);

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my ($self, $login, $conn, $cb) = @_;

  unless($self->_valid_connection_args($conn, $cb)) {
    return $self;
  }

  my @channels = $self->_parse_channels(delete $conn->{channels});
  my $key = join ':', "user:$login:connection:$conn->{server}";

  warn "[core:$login] add (", join(', ', %$conn), ")\n" if DEBUG;
  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->exists($key, $delay->begin);
    },
    sub {
      my($delay, $exists) = @_;

      return $self->$cb({ server => 'Connection exists' }, undef) if $exists;
      return $self->redis->execute(
        [sadd => "connections", "$login:$conn->{server}"],
        [sadd => "user:$login:connections", $conn->{server}],
        [hmset => "user:$login:connection:$conn->{server}", %$conn],
        (map { [ zadd => "user:$login:conversations", time, as_id $conn->{server}, $_ ] } @channels),
        $delay->begin,
      );
    },
    sub {
      my($delay, @saved) = @_;
      $self->control(start => $login => $conn->{server}, $delay->begin);
    },
    sub {
      my($delay, $started) = @_;
      $self->$cb(undef, $conn);
    },
  );
}

=head2 update_connection

  $self->update_connection($login => {
    server => $str, # irc_server[:port]
    lookup => $str, # irc_server[:port]
    nick => $str,
    user => $str,
    channels => [ '#foo', '#bar', '...' ],
    tls => $bool,
  }, $callback);

Update a connection's settings and reconnect.

=cut

sub update_connection {
  my ($self, $login, $conn, $cb) = @_;
  my $lookup = delete $conn->{lookup};

  if(!$self->_valid_connection_args($conn, $cb)) {
    return $self;
  }
  if($conn->{server} eq $lookup) {
    return $self->_update_connection($login, $conn, $cb);
  }

  warn "[core:$login] add/delete $lookup\n";
  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->add_connection($login => $conn, $delay->begin);
    },
    sub {
      my($delay, $error, $res) = @_;
      return $self->$cb($error, undef) if $error;
      return $self->delete_connection($login => $lookup, $delay->begin);
    },
    sub {
      my($delay, $error) = @_;
      # TODO: How to handle error?
      return $self->$cb('', $conn);
    },
  );

  return $self;
}

sub _update_connection {
  my($self, $login, $conn, $cb) = @_;
  my @wanted_channels = $self->_parse_channels(delete $conn->{channels});

  warn "[core:$login] update (", join(', ', %$conn), ")\n" if DEBUG;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hgetall("user:$login:connection:$conn->{server}", $delay->begin);
      $self->redis->zrange("user:$login:conversations", 0, 1, $delay->begin);
    },
    sub {
      my($delay, $found, $existing_channels) = @_;
      my %channels;

      unless($found) {
        return $self->$cb('Connection does not exist', undef);
      }

      delete $found->{$_} for qw/ server host /; # want these values
      $conn->{$_} ~~ $found->{$_} and delete $conn->{$_} for keys %$found;
      $existing_channels = { map { $_, 1 } grep { /^#/ } map { (id_as $_)[1] } @$existing_channels };

      if(%$conn) {
        $self->redis->hmset("user:$login:connection:$conn->{server}", %$conn, $delay->begin)
      }
      if($conn->{nick}) {
        $self->redis->publish("wirc:user:$login:$conn->{server}", "dummy-uuid NICK $conn->{nick}", $delay->begin);
        warn "[core:$login] NICK $conn->{nick}\n" if DEBUG;
      }
      for my $channel (@wanted_channels) {
        next if delete $existing_channels->{$channel};
        $self->redis->publish("wirc:user:$login:$conn->{server}", "dummy-uuid JOIN $channel", $delay->begin);
        warn "[core:$login] JOIN $channel\n" if DEBUG;
      }
      for my $channel (keys %$existing_channels) {
        $self->redis->publish("wirc:user:$login:$conn->{server}", "dummy-uuid PART $channel", $delay->begin);
        warn "[core:$login] PART $channel\n" if DEBUG;
      }

      $delay->begin->();
    },
    sub {
      my($delay, @saved) = @_;
      $self->$cb('', $conn);
    },
  );

  return $self;
}

=head2 delete_connection

  $self->delete_connection($login, $server, $cb);

=cut

sub delete_connection {
  my($self, $login, $server, $cb) = @_;

  warn "[core:$login] delete $server\n" if DEBUG;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->srem("connections", "$login:$server", $delay->begin);
      $self->redis->srem("user:$login:connections", $server, $delay->begin);
      $self->redis->del("user:$login:connection:$server", $delay->begin);
    },
    sub {
      my ($delay, @removed) = @_;
      return $self->$cb('Unknown connection') unless grep $_, @removed;
      $self->redis->keys("user:$login:connection:$server:*", $delay->begin); # jht: not sure if i like this...
      $self->redis->zrange("user:$login:conversations", 0, -1, $delay->begin);
    },
    sub {
      my ($delay, $keys, $conversations) = @_;
      $self->redis->del(@$keys, $delay->begin);
      $self->redis->zrem("user:$login:conversations", $_) for grep { /^$server:/ } @$conversations;
      $self->control(stop => $login => $server, $delay->begin);
    },
    sub {
      my($delay, @deleted) = @_;
      $self->$cb('');
    },
  );
}

=head2 ctrl_stop

    $self->ctrl_stop($login, $server);

Stop a connection by connection id.

=cut

sub ctrl_stop {
  my ($self, $login, $server) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$login}{$server}) {
    $conn->disconnect(sub { delete $self->{connections}{$login}{$server} });
  }
}

=head2 ctrl_restart

    $self->ctrl_restart($login, $server);

Restart a connection by connection id.

=cut


sub ctrl_restart {
  my ($self, $login, $server) = @_;

  Scalar::Util::weaken($self);

  if(my $conn = $self->{connections}{$login}{$server}) {
    $conn->disconnect(sub {
      delete $self->{connections}{$login}{$server};
      $self->ctrl_start($login => $server);
    });
  }
  else {
    $self->ctrl_start($login => $server);
  }
}

=head2 ctrl_start

Start a single connection by connection id.

=cut

sub ctrl_start {
  my ($self, $login, $server) = @_;
  $self->_connection(login => $login, server => $server)->connect;
}

=head2 login

  $self->login({ login => $str, password => $str }, $callback);

Will call callback after authenticating the user. C<$callback> will receive
either:

  $callback->($self, $login); # success
  $callback->($self, undef, $error); # on error

=cut

sub login {
  my ($self, $params, $cb) = @_;
  my $login = $params->{login};

  unless($login) {
    return $self->$cb('login is required');
  }

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hget("user:$login", "digest", $delay->begin);
    },
    sub {
      my ($delay, $digest) = @_;
      if(!$digest) {
        $self->$cb('No such user.');
      }
      elsif (crypt($params->{password}, $digest) eq $digest) {
        warn "[core:$login] Valid password\n" if DEBUG;
        $self->$cb('');
      }
      else {
        $self->$cb('Could not verify digest.');
      }
    }
  );
}

sub _parse_channels {
  my $self = shift;
  my $channels = shift || [];
  my %dup;
  sort grep { $_ ne '#' and !$dup{$_}++ } map { /^#/ ? $_ : "#$_" } map { split m/[\s,]+/ } @$channels;
}

sub _valid_connection_args {
  my($self, $conn, $cb) = @_;
  my %errors;

  if(!$conn->{server}) { # back compat
    $conn->{server} = delete $conn->{host};
  }

  for my $name (qw/ server nick user /) {
    next if $conn->{$name};
    $errors{$name} = "$name is required.";
  }

  if($conn->{server} and $conn->{server} !~ $WebIrc::Core::Util::SERVER_NAME_RE) {
    $errors{server} = "Invalid server";
  }

  return 1 unless %errors;
  $self->$cb(\%errors);
  return 0;
}

sub DESTROY {
  my $self = shift;
  delete $self->{$_} for qw/ control redis /;
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
