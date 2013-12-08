package Convos::Loopback;

=head1 NAME

Convos::Loopback - Loopback connection

=head1 DESCRIPTION

This class represents a loopback connection. That is a connection which is
only visible internally to convos, and thus does not require a IRC server.

This module must be compatible with L<Mojo::IRC>.

=head1 SYNOPSIS

  my $connection = Convos::Core::Connection->new(....);
  my $loopback = Convos::Loopback->new(connection => $connection);

  $loopback->connect(sub {
    my($loopback, $error) = @_;
    # ...
  });

=cut

use Mojo::Base -base;
use constant DEBUG => $ENV{MOJO_IRC_DEBUG} ? 1 : 0;

=head1 ATTRIBUTES

=head2 server

Cannot be set. Will always return "loopback".

=head2 nick

Holds the nick.

=head2 user

Alias for L</nick>.

=cut

has nick => '';
sub server { 'loopback' }
sub user { shift->nick }

=head2 ioloop

Holds an instance of L<Mojo::IOLoop>.

=head2 redis

Holds an instance of L<Mojo::Redis>.

=cut

has ioloop => sub { shift->redis->ioloop };
has redis => sub { shift->connection->redis };

=head2 connection

Holds and instance of L<Convos::Core::Connection>. Must be provided in
constructor.

=cut

sub connection { shift->{connection} }

=head1 METHODS

=head2 new

Used to create a new object. L</connection> is required parameter.

=cut

sub new {
  my $self = Mojo::Base::new(@_);
  $self->{connection} or die 'connection is required';
  $self->{debug_key} = join ':', $self->server, $self->user;
  Scalar::Util::weaken($self->{connection});
  $self;
}

=head2 change_nick

Used to change L</nick>.

=cut

sub change_nick {
  my($self, $nick) = @_;
  my $old = $self->nick // '';

  return $self unless defined $nick;
  return $self if $old and $old eq $nick;
  $self->_register_nick($nick, sub {});
  $self;
}

=head2 connect

  $self->connect($cb);

Will start subscribing to messages sent to this nick.

=cut

sub connect {
  my($self, $cb) = @_;

  if($self->{connected}) {
    return $self->$cb('');
  }

  $self->{debug_key} = join ':', $self->server, $self->user;
  $self->_register_nick($self->nick, sub {
    my($self, $new, $old) = @_;
    $self->connection->irc_rpl_welcome({});
    $self->$cb('');
  });

  Scalar::Util::weaken($self);
  $self->{messages} = $self->redis->subscribe("convos:loopback");
  $self->{messages}->on(message => sub {
    my $message = Parse::IRC::parse_irc($_[1]);
    my $method = lc('irc_' .($message->{command} || 'error'));
    my $nick = $self->nick;

    warn "[$self->{debug_key}] >>> $_[1] ($method)\n" if DEBUG;

    return $self->connection->$method($message) if $self->connection->can($method);
    return $self->connection->irc_error($message) if $method =~ m/^irc_err/i;
  });

  $self;
}

sub _register_nick {
  my($self, $new, $cb) = @_;
  my $old = $self->nick;

  $self->_redis_execute([ sismember => "convos:loopback:names", $new ], sub {
    my($self, $taken) = @_;

    return $self->_register_nick($new .'_', $cb) if $taken;
    $self->redis->sadd("convos:loopback:names", $new);
    $self->_nick_changed($old, $new);
    $self->$cb($new, $old);
  });
}

sub _nick_changed {
  my($self, $old, $new) = @_;

  if($old ne $new) {
    delete $self->{conversation}{$old};
    $self->_publish("NICK :$new");
    $self->redis->srem("convos:loopback:names", $old);
    $self->redis->zrange($self->connection->{conversation_path}, 0, -1, sub {
      my($redis, $conversations) = @_;
      for($self->connection->channels_from_conversations($conversations)) {
        $redis->srem("convos:loopback:$_:names", $old);
        $redis->sadd("convos:loopback:$_:names", $new);
      }
    });
  }

  $self->nick($new);
  $self->{conversation}{$new} = $self->redis->subscribe("convos:loopback:$new");
  $self->{conversation}{$new}->on(message => sub { $self and $self->_message_from($new, $_[1]) });
}

sub _publish {
  my($self, $message) = @_;
  $self->redis->publish(
    "convos:loopback",
    sprintf(':%s!~%s\@loopback %s', $self->nick, $self->nick, $message),
  );
}

=head2 disconnect

Does nothing.

=cut

sub disconnect { shift }

=head2 write

See L<Mojo::IRC/write>.

=cut

sub write {
  my $cb = ref $_[-1] eq 'CODE' ? pop : sub {};
  my $self = shift;
  my $cmd = join ' ', @_;
  my $nick = $self->nick;
  my($method, @args);

  if($cmd =~ /^:$nick (\w+)\s?(.*)/) {
    $method = $1;
    @args = split ' ', $2;
  }
  else {
    ($method, @args) = split ' ', $cmd;
  }

  if($method = $self->can(lc "_write_$method")) {
    $self->$method(@args)->$cb('');
  }
  else {
    $self->$cb("Unknown command: $cmd");
  }
}

sub _message_from {
  my($self, $target, $message) = @_;
  my $sender = $message =~ s/^:(\w+)\s// ? $1 : $self->nick;
  return if $sender eq $self->nick;
  return $self->connection->add_message({
    params => [ $target, $message ],
    prefix => "$sender\@loopback",
  });
}

sub _write_join {
  my($self, $channel) = @_;

  Scalar::Util::weaken($self);
  $self->{conversation}{$channel} = $self->redis->subscribe("convos:loopback:$channel");
  $self->{conversation}{$channel}->once(data => sub {
    $self->redis->sadd("convos:loopback:$channel:names", $self->nick);
    $self->_publish("JOIN $channel");
  });
  $self->{conversation}{$channel}->on(message => sub {
    $self and $self->_message_from($channel, $_[1]);
  });

  $self;
}

sub _write_names {
  my($self, $channel) = @_;

  $self->_redis_execute([ smembers => "convos:loopback:$channel:names" ], sub {
    my($self, $names) = @_;
    $self->connection->irc_rpl_namreply({ params => ['', '', $channel, join ' ', @$names] });
  });
}

sub _write_nick {
  my($self, $new) = @_;
  my $old = $self->nick;

  $new or return;
  $self->_redis_execute([ sadd => "convos:loopback:names", $new ], sub {
    my($self, $added) = @_;

    if($added) {
      $self->_nick_changed($old, $new);
      $self->connection->cmd_nick({ params => [$new] });
    }
    else {
      $self->connection->irc_error({ params => ['Nickname is already in use'] });
    }
  });
}

sub _write_part {
  my($self, $channel) = @_;
  my $nick = $self->nick;

  $self->_redis_execute([ srem => "convos:loopback:$channel:names", $self->nick ], sub {
    my($self, $parted) = @_;
    $self->_publish("PART $channel");
  })
}

sub _write_privmsg {
  my($self, $target, @msg) = @_;

  local $" = ' ';
  $msg[0] =~ s/^://;
  $self->redis->publish("convos:loopback:$target", sprintf ':%s %s', $self->nick, "@msg");
}

sub _write_topic {
  my($self, $channel, @topic) = @_;
  my $topic = join ' ', @topic;

  if($topic) {
    $topic =~ s/^://;
    $self->_redis_execute([ hset => "convos:loopback:$channel", "topic", $topic ], sub {
      my($self) = @_;
      $self->_publish("TOPIC $channel :$topic");
    });
  }
  else {
    $self->_redis_execute([ hget => "convos:loopback:$channel", "topic" ], sub {
      my($self, $topic) = @_;
      $self->connection->irc_rpl_topic({ params => ['', $channel, $topic // ''] });
    });
  }
}

sub _redis_execute {
  my $cb = pop;
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->redis->execute(@_, sub { shift; $self and $self->$cb(@_) });
  $self;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
