package Convos::Core;

=head1 NAME

Convos::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use Mojolicious::Validator;
use Convos::Core::Connection;
use Convos::Core::Util qw( as_id id_as );
use constant DEBUG => $ENV{CONVOS_DEBUG} // 0;

=head1 ATTRIBUTES

=head2 log

Holds a L<Mojo::Log> object.

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has log => sub { Mojo::Log->new };
has redis => sub { Mojo::Redis->new };

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
      $self->redis->del('convos:loopback:names'); # clear loopback nick list
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
    $conn = Convos::Core::Connection->new(redis => $self->redis, %args);
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
      Mojo::IOLoop->timer(0.5, sub { $self and $self->_start_control_channel })
    },
  );
}

=head2 add_connection

  $self->add_connection({
    channels => [ '#foo', '#bar', '...' ],
    login => $str,
    nick => $str,
    server => $str, # irc_server[:port]
    tls => $bool,
  }, $callback);

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my($self, $input, $cb) = @_;
  my $validation = $self->_validation($input, qw( password login nick server tls ));

  $validation->input->{user} ||= $validation->input->{login};

  if($validation->has_error) {
    $self->$cb($validation, undef);
    return $self;
  }

  my($login, $server) = $validation->param([qw( login server )]);
  my @channels = $self->_parse_channels(delete $validation->input->{channels});
  my $key = join ':', "user:$login:connection:$server";

  warn "[core:$login] add ", _dumper($validation->input), "\n" if DEBUG;
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
        [sadd => "connections", "$login:$server"],
        [sadd => "user:$login:connections", $server],
        [hmset => "user:$login:connection:$server", %{ $validation->input }],
        (map { [ zadd => "user:$login:conversations", time, as_id $server, $_ ] } @channels),
        $delay->begin,
      );
    },
    sub {
      my($delay, @saved) = @_;
      $self->control(start => $validation->param([qw( login server )]), $delay->begin);
    },
    sub {
      my($delay, $started) = @_;
      $self->$cb(undef, $validation->input);
    },
  );
}

=head2 update_connection

  $self->update_connection({
    channels => [ '#foo', '#bar', '...' ],
    login => $str,
    lookup => $str, # irc_server[:port]
    nick => $str,
    server => $str, # irc_server[:port]
    tls => $bool,
  }, $callback);

Update a connection's settings and reconnect.

=cut

sub update_connection {
  my($self, $input, $cb) = @_;
  my $validation = $self->_validation($input, qw( password login lookup nick server tls ));
  my $lookup;

  $validation->input->{user} ||= $validation->input->{login};
  $lookup = delete $validation->input->{lookup} || '';

  if($validation->has_error) {
    $self->$cb($validation, undef);
    return $self;
  }
  if($validation->param('server') eq $lookup) {
    $self->_update_connection($validation, $cb);
    return $self;
  }

  warn "[core:@{[$validation->param('login')]}] delete+add $lookup\n";
  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->add_connection($validation, $delay->begin);
    },
    sub {
      my($delay, $error, $res) = @_;
      return $self->$cb($error, undef) if $error;
      local $validation->input->{server} = $lookup;
      return $self->delete_connection($validation, $delay->begin);
    },
    sub {
      my($delay, $error) = @_; # TODO: How to handle error?
      $self->$cb(undef, $validation->input);
    },
  );

  return $self;
}

sub _update_connection {
  my($self, $validation, $cb) = @_;
  my @wanted_channels = $self->_parse_channels(delete $validation->input->{channels});
  my($conn, $login, $server);

  ($login, $server) = $validation->param([qw( login server )]);
  warn "[core:$login] update ", _dumper($validation->input), "\n" if DEBUG;
  $conn = $self->_connection(%{ $validation->input });

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hgetall("user:$login:connection:$server", $delay->begin);
      $self->redis->zrange("user:$login:conversations", 0, 1, $delay->begin);
    },
    sub {
      my($delay, $found, $conversations) = @_;
      my %existing_channels;

      unless($found and %$found) {
        $validation->error(server => ['no_such_connection']);
        $self->$cb($validation, undef);
        return $self;
      }

      %existing_channels = map { $_, 1 } $conn->channels_from_conversations($conversations);
      $conn = {};

      for my $k (qw( login nick server tls password )) {
        my $value = $validation->param($k) or next;
        $conn->{$k} = $value;
      }
      for my $k (qw( server host )) { # want these values
        delete $found->{$k};
      }
      for my $k (keys %$found) {
        next unless defined $conn->{$k} and defined $found->{$k};
        next unless $found->{$k} eq $conn->{$k};
        delete $conn->{$k}; # only keep changed keys
      }

      if(%$conn) {
        $self->redis->hmset("user:$login:connection:$server", %$conn, $delay->begin)
      }
      if($conn->{nick}) {
        $self->redis->publish("convos:user:$login:$server", "dummy-uuid NICK $conn->{nick}", $delay->begin);
        warn "[core:$login] NICK $conn->{nick}\n" if DEBUG;
      }

      for my $channel (@wanted_channels) {
        next if delete $existing_channels{$channel};
        $self->redis->zadd("user:$login:conversations", time, as_id $server, $channel);
        $self->redis->publish("convos:user:$login:$server", "dummy-uuid JOIN $channel", $delay->begin);
        warn "[core:$login] JOIN $channel\n" if DEBUG;
      }
      for my $channel (keys %existing_channels) {
        $self->redis->zrem("user:$login:conversations", time, as_id $server, $channel);
        $self->redis->publish("convos:user:$login:$server", "dummy-uuid PART $channel", $delay->begin);
        warn "[core:$login] PART $channel\n" if DEBUG;
      }

      $delay->begin->();
    },
    sub {
      my($delay, @saved) = @_;
      $self->$cb(undef, $conn);
    },
  );

  return $self;
}

=head2 delete_connection

  $self->delete_connection({
    login => $str,
    server => $str,
  }, $cb);

=cut

sub delete_connection {
  my($self, $input, $cb) = @_;
  my $validation = $self->_validation($input);
  my($login, $server);

  $validation->required('login');
  $validation->required('server');

  if($validation->has_error) {
    $self->$cb($validation);
    return $self;
  }

  ($login, $server) = $validation->param([qw( login server )]);

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

      unless(grep $_, @removed) {
        $validation->error(server => ['no_such_connection']);
        $self->$cb($validation);
        return $self;
      }

      $self->redis->keys("user:$login:connection:$server:*", $delay->begin); # jht: not sure if i like this...
      $self->redis->zrange("user:$login:conversations", 0, -1, $delay->begin);
    },
    sub {
      my($delay, $keys, $conversations) = @_;
      my $prefix = as_id $server;
      $self->redis->del(@$keys, $delay->begin) if @$keys;
      $self->redis->zrem("user:$login:conversations", $_) for grep { /^$prefix:00/ } @$conversations;
      $self->control(stop => $login, $server, $delay->begin);
    },
    sub {
      my($delay, @deleted) = @_;
      $self->$cb(undef);
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

  $callback->($self, ''); # success
  $callback->($self, 'error message'); # on error

=cut

sub login {
  my ($self, $input, $cb) = @_;
  my $validation = $self->_validation($input);

  $validation->required('login');
  $validation->required('password');

  if($validation->has_error) {
    $self->$cb($validation);
    return $self;
  }

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hget("user:" .$validation->param('login'), "digest", $delay->begin);
    },
    sub {
      my ($delay, $digest) = @_;
      if(!$digest) {
        $validation->error(login => ['no_such_user']);
        $self->$cb($validation);
      }
      elsif ($digest eq crypt scalar $validation->param('password'), $digest) {
        warn "[core:@{[$validation->param('login')]}] Valid password\n" if DEBUG;
        $self->$cb(undef);
      }
      else {
        $validation->error(login => ['invalid_password']);
        $self->$cb($validation);
      }
    }
  );
}

sub _parse_channels {
  my $self = shift;
  my $channels = shift || [];
  my %dup;

  sort
  grep { $_ ne '#' and !$dup{$_}++ }
  map { /^#/ ? $_ : "#$_" }
  map { split m/[\s,]+/ }
  @$channels;
}

sub _dumper { # function
  Data::Dumper->new([@_])->Indent(0)->Sortkeys(1)->Terse(1)->Dump
}

sub _validation {
  my($self, $input, @names) = @_;
  my $validation;

  if(UNIVERSAL::isa($input, 'Mojolicious::Validator::Validation')) {
    $validation = $input;
  }
  else {
    $validation = Mojolicious::Validator->new->validation(input => $input);
  }

  for my $k (@names) {
    if($k eq 'password') { $validation->optional('password') }
    elsif($k eq 'login') { $validation->required('login')->size(3, 30) }
    elsif($k eq 'nick') { $validation->required('nick')->size(1, 30) }
    elsif($k eq 'server') { $validation->required('server')->like($Convos::Core::Util::SERVER_NAME_RE) }
    elsif($k eq 'tls') { $validation->required('tls')->in(0, 1) }
    else { $validation->required($k) }
  }

  $validation;
}

sub DESTROY {
  my $self = shift;
  delete $self->{$_} for qw/ control redis /;
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
