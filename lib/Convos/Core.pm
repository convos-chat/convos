package Convos::Core;

=head1 NAME

Convos::Core - TODO

=head1 SYNOPSIS

TODO

=cut

use Mojo::Base -base;
use Mojo::JSON 'j';
use Mojolicious::Validator;
use Convos::Core::Connection;
use Convos::Core::Util qw( as_id id_as );
use Time::HiRes qw( time );
use constant CONNECT_INTERVAL => $ENV{CONVOS_CONNECT_INTERVAL} || 2;
use constant DEBUG => $ENV{CONVOS_DEBUG} // 0;

=head1 ATTRIBUTES

=head2 archive

Holds a L<Convos::Archive::File> object.

=head2 log

Holds a L<Mojo::Log> object.

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has archive => sub { require Convos::Archive::File; Convos::Archive::File->new; };
has log     => sub { Mojo::Log->new };
has redis   => sub { die 'redis connection required in constructor' };

=head1 METHODS

=head2 control

  $self->control($command, $cb);

Used to issue a control command.

=cut

sub control {
  my ($self, @args) = @_;
  my $cb = pop @args;

  $self->redis->lpush('core:control', join(':', @args), $cb);
  $self;
}

=head2 start

Will fetch connection information from the database and try to connect to them.

=cut

sub start {
  my $self = shift;

  die "Convos::Core is already started" if $self->{start}++;

  # TODO: Remove in future versions and/or move to Convos::Upgrader
  $self->redis->del($_)
    for qw( convos:backend:lock convos:backend:pid convos:backend:started convos:host2convos convos:loopback:names );

  $self->redis->del('core:control');    # need to clear instructions queued while backend was stopped
  $self->_start_control_channel;

  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->smembers('connections', $delay->begin);
    },
    sub {
      my ($delay, $connections) = @_;
      for my $id (@$connections) {
        $self->_connection($id)->_state('disconnected')->{core_connect_timer} = 1;
      }
    },
  );

  $self->{connect_tid} ||= Mojo::IOLoop->recurring(
    CONNECT_INTERVAL,
    sub {
      for my $conn (values %{$self->{connections}}) {
        next if --$conn->{core_connect_timer};
        $conn->connect;
        last;
      }
    }
  );

  return $self;
}

sub _start_control_channel {
  my $self = shift;
  my $cb;

  Scalar::Util::weaken($self);

  $cb = sub {
    my ($redis, $instruction) = @_;
    $redis->brpop($instruction->[0], 0, $cb);
    $instruction->[1] or return;
    my ($command, $login, $name) = split /:/, $instruction->[1];
    my $action = "ctrl_$command";
    $self->$action($login, $name);
  };

  $self->{control} = Mojo::Redis->new(server => $self->redis->server);
  $self->{control}->$cb(['core:control']);
  $self->{control}->on(
    error => sub {
      my ($redis, $error) = @_;
      $self->log->error("[core:control] Stopping Mojo::IOLoop on 'core:control' error: $error ");
      Mojo::IOLoop->stop;
    },
  );
}

=head2 add_connection

  $self->add_connection({
    login => $str,
    name => $str,
    nick => $str,
    server => $str, # irc_server[:port]
  }, $callback);

Add a new connection to redis. Will create a new connection id and
set all the keys in the %connection hash

=cut

sub add_connection {
  my ($self, $input, $cb) = @_;
  my $validation = $self->_validation($input, qw( login name nick password server username ));

  if ($validation->has_error) {
    $self->$cb($validation, undef);
    return $self;
  }

  my ($login, $name) = $validation->param([qw( login name )]);

  warn "[core:$login] add ", _dumper($validation->output), "\n" if DEBUG;
  Scalar::Util::weaken($self);
  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->exists("user:$login:connection:$name", $delay->begin);
    },
    sub {
      my ($delay, $exists) = @_;

      if ($exists) {
        $validation->error(name => ['exists']);
        $self->$cb($validation, undef);
        return;
      }

      $self->redis->execute(
        [sadd  => "connections",                  "$login:$name"],
        [sadd  => "user:$login:connections",      $name],
        [hmset => "user:$login:connection:$name", %{$validation->output}, state => 'disconnected'],
        $delay->begin,
      );
    },
    sub {
      my ($delay, @saved) = @_;
      $self->control(start => $login, $name, $delay->begin);
    },
    sub {
      my ($delay, $started) = @_;
      $self->$cb($validation, $validation->output);
    },
  );
}

=head2 update_connection

  $self->update_connection({
    login => $str,
    name => $str,
    nick => $str,
    server => $str, # irc_server[:port]
  }, $callback);

Update a connection's settings. This might issue a reconnect or issue
IRC commands to reflect the changes.

=cut

sub update_connection {
  my ($self, $input, $cb) = @_;
  my $validation = $self->_validation($input, qw( login name nick password server username ));

  if ($validation->has_error) {
    $self->$cb($validation, undef);
    return $self;
  }

  my ($login, $name) = $validation->param([qw( login name )]);
  my $conn  = Convos::Core::Connection->new(%{$validation->output});
  my $redis = $self->redis;

  warn "[core:$login] update ", _dumper($validation->output), "\n" if DEBUG;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->hgetall("user:$login:connection:$name", $delay->begin);
    },
    sub {
      my ($delay, $current) = @_;

      unless ($current and %$current) {
        $validation->error(name => ['no_such_connection']);
        $self->$cb($validation, undef);
        return;
      }

      $delay->begin->(@_);    # pass on $current and $conversations
      $redis->zrange("user:$login:conversations", 0, 1, $delay->begin);
      $redis->hmset("user:$login:connection:$name", $validation->output, $delay->begin);
    },
    sub {
      my ($delay, $current, $conversations) = @_;

      $conn = $validation->output;    # get rid of the extra junk from Connection->new()

      if ($current->{server} ne $conn->{server}) {
        $self->control(restart => $login, $name, sub { });
        $self->$cb(undef, $conn);
        return;
      }
      if ($current->{nick} ne $conn->{nick}) {
        warn "[core:$login] NICK $conn->{nick}\n" if DEBUG;
        $redis->publish("convos:user:$login:$name", "dummy-uuid NICK $conn->{nick}");
      }

      $self->$cb(undef, $conn);
    },
  );

  return $self;
}

=head2 delete_connection

  $self->delete_connection({
    login => $str,
    name => $str,
  }, $cb);

=cut

sub delete_connection {
  my ($self, $input, $cb) = @_;
  my $validation = $self->_validation($input);

  $validation->required('login');
  $validation->required('name');

  if ($validation->has_error) {
    $self->$cb($validation);
    return $self;
  }

  my ($login, $name) = $validation->param([qw( login name )]);

  warn "[core:$login] delete $name\n" if DEBUG;
  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->del("user:$login:connection:$name", $delay->begin);
      $self->redis->srem("connections",             "$login:$name", $delay->begin);
      $self->redis->srem("user:$login:connections", $name,          $delay->begin);
    },
    sub {
      my ($delay, @removed) = @_;

      unless ($removed[0]) {
        $validation->error(name => ['no_such_connection']);
        $self->$cb($validation);
        return $self;
      }

      $self->redis->keys("user:$login:connection:$name*", $delay->begin);    # jht: not sure if i like this...
      $self->redis->zrange("user:$login:conversations", 0, -1, $delay->begin);
      $self->control(stop => $login, $name, $delay->begin);
    },
    sub {
      my ($delay, $keys, $conversations) = @_;
      $self->redis->del(@$keys, $delay->begin) if @$keys;
      $self->redis->zrem("user:$login:conversations", $_) for grep {/^$name\b/} @$conversations;
      $self->$cb(undef);
    },
  );
}

=head2 delete_user

  $self = $self->delete_user(
            { login => $str },
            sub { my ($self, $err) = @_; ... },
          );

This method will delete a user and all the conversations, connections, and
related data. It will also stop all the connections.

=cut

sub delete_user {
  my ($self, $input, $cb) = @_;
  my $redis = $self->redis;
  my $login = $input->{login};

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->smembers("user:$login:connections", $delay->begin);
      $redis->keys("user:$login:*", $delay->begin);
    },
    sub {
      my ($delay, $connections, $keys) = @_;

      $redis->del(@$keys, $delay->begin) if @$keys;
      $redis->del("user:$login", $delay->begin);
      $redis->srem("users", $login, $delay->begin);

      for my $name (@$connections) {
        my $conn = $self->_connection("$login:$name");
        $self->control(stop => $login, $name, $delay->begin);
        $self->archive->flush($conn);
        $redis->srem("connections", "$login:$name", $delay->begin);
      }
    },
    sub {
      my ($delay, @deleted) = @_;
      $self->$cb('');
    },
  );

  return $self;
}

=head2 ctrl_stop

  $self->ctrl_stop($login, $server);

Stop a connection by connection id.

=cut

sub ctrl_stop {
  my ($self, $login, $server) = @_;
  my $id = join ':', $login, $server;
  my $conn = $self->{connections}{$id} or return;

  Scalar::Util::weaken($self);
  $conn->disconnect(sub { delete $self->{connections}{$id} });
}

=head2 ctrl_restart

  $self->ctrl_restart($login, $server);

Restart a connection by connection id.

=cut

sub ctrl_restart {
  my ($self, $login, $server) = @_;
  my $id = join ':', $login, $server;

  if (my $conn = $self->{connections}{$id}) {
    Scalar::Util::weaken($self);
    $conn->disconnect(
      sub {
        delete $self->{connections}{$id};
        $self->ctrl_start($login => $server);
      }
    );
  }
  else {
    $self->ctrl_start($login => $server);
  }
}

=head2 ctrl_start

Start a single connection by connection id.

=cut

sub ctrl_start {
  my ($self, $login, $name) = @_;
  $self->_connection("$login:$name")->connect;
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
  my $output;

  $validation->required('login');
  $validation->required('password');

  if ($validation->has_error) {
    $self->$cb($validation);
    return $self;
  }

  $output = $validation->output;
  $output->{login} = lc $output->{login};

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->hget("user:$output->{login}", "digest", $delay->begin);
    },
    sub {
      my ($delay, $digest) = @_;
      if (!$digest) {
        $validation->error(login => ['no_such_user']);
        $self->$cb($validation);
      }
      elsif ($digest eq crypt scalar $validation->param('password'), $digest) {
        warn "[core:$output->{login}] Valid password\n" if DEBUG;
        $self->$cb(undef);
      }
      else {
        $validation->error(login => ['invalid_password']);
        $self->$cb($validation);
      }
    }
  );
}

sub _connection {
  my ($self, $id) = @_;
  my $conn = $self->{connections}{$id};

  unless ($conn) {
    my ($login, $name) = split /:/, $id;
    Scalar::Util::weaken($self);
    $conn = Convos::Core::Connection->new(redis => $self->redis, log => $self->log, login => $login, name => $name);
    $conn->on(save => sub { $_[1]->{message} and $_[1]->{timestamp} and $self->archive->save(@_); });
    $self->{connections}{$id} = $conn;
  }

  $conn;
}

sub _dumper {    # function
  Data::Dumper->new([@_])->Indent(0)->Sortkeys(1)->Terse(1)->Dump;
}

sub _validation {
  my ($self, $input, @names) = @_;
  my $validation;

  if (UNIVERSAL::isa($input, 'Mojolicious::Validator::Validation')) {
    $validation = $input;
  }
  else {
    $validation = Mojolicious::Validator->new->validation;
    $validation->input($input);
  }

  for my $k (@names) {
    if    ($k eq 'password') { $validation->optional('password') }
    elsif ($k eq 'username') { $validation->optional('username') }
    elsif ($k eq 'login')    { $validation->required('login')->size(3, 30) }
    elsif ($k eq 'name')     { $validation->required('name')->like(qr{^[-a-z0-9]+$}) }    # network name
    elsif ($k eq 'nick')     { $validation->required('nick')->size(1, 30) }
    elsif ($k eq 'server') { $validation->required('server')->like($Convos::Core::Util::SERVER_NAME_RE) }
    else                   { $validation->required($k) }
  }

  $validation;
}

sub DESTROY {
  my $self = shift;
  my $tid;

  Mojo::IOLoop->remove($tid) if $tid = $self->{connect_tid};
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
