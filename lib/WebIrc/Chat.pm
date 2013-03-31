package WebIrc::Chat;

=head1 NAME

WebIrc::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';

my $JSON = Mojo::JSON->new;
my %COMMANDS = (
  j     => 'JOIN',
  join  => 'JOIN',
  t     => sub { my $data = pop; "TOPIC $data->{target}" . ($data->{cmd} ? ' :' . $data->{cmd} : '') },
  topic => sub { my $data = pop; "TOPIC $data->{target}" . ($data->{cmd} ? ' :' . $data->{cmd} : '') },
  w     => 'WHOIS',
  whois => 'WHOIS',
  nick  => 'NICK',
  me   => sub { my $data = pop; "PRIVMSG $data->{target} :\x{1}ACTION $data->{cmd}\x{1}" },
  msg  => sub { my $data = pop; $data->{cmd} =~ s!^(\w+)\s*!!; "PRIVMSG $1 :$data->{cmd}" },
  part => sub { my $data = pop; "PART " . ($data->{cmd} || $data->{target}) },
  query=> sub {
    my ($self, $data) = @_;
    my $target = $data->{cmd} || $data->{target};
    $self->redis->sadd(
      "connection:@{[$data->{cid}]}:conversations",
      $target,
      sub {
        my ($redis, $member) = @_;
        return unless $member;
        $self->send_partial( 'event/new_conversation', cid => $data->{cid}, target => $target);
      }
    );
    return;
  },
  close => sub {
    my ($self, $data) = @_;
    my $target = $data->{cmd} || $data->{target};
    $self->redis->sismember(
      "connection:@{[$data->{cid}]}:conversations",
      $target,
      sub {
        my ($redis, $member) = @_;
        return unless $member;
        $self->redis->srem("connection:@{[$data->{cid}]}:conversations", $target);
        $self->send_partial( 'event/remove_conversation', cid => $data->{cid}, target => $target);
      }
    );
    return;
  },
  reconnect => sub {
    my ($self, $data) = @_;
    $self->redis->publish('core:control', "restart:" . $data->{cid});
    return;
  },

  help => sub {
    my ($self, $data) = @_;
    $self->send_partial(
      'event/wirc_notice',
      message => "Available Commands:\nj\tw\tme\tmsg\tpart\tnick\thelp"
    );
    return;
  }
);

=head1 METHODS

=head2 parse_command

Takes a websocket command, parses it into a IRC resposne.

=cut

sub parse_command {
  my ($self, $data) = @_;

  if(!length $data->{cmd}) {
    1;
  }
  elsif ($data->{cmd} =~ s!^/(\w+)\s*!!) {
    my ($cmd) = $1;
    if (my $irc_cmd = $COMMANDS{$cmd}) {
      return $irc_cmd->($self, $data) if (ref $irc_cmd);
      return $irc_cmd . ' ' . $data->{cmd};
    }
    else {
      $self->send_partial('event/wirc_notice', message => 'Unknown command');
    }
  }
  elsif($data->{target}) {
    return "PRIVMSG $data->{target} :$data->{cmd}";
  }

  return;
}

=head2 socket

Handle conversation exchange over websocket.

=cut

sub socket {
  my $self = shift->render_later;
  my $uid  = $self->session('uid');

  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

  $self->redis->smembers(
    "user:$uid:connections",
    sub {
      my ($redis, $cids) = @_;
      my %allowed = map { $_ => 1 } @$cids;

      $self->_subscribe_to_server_messages($_) for @$cids;
      $self->on(
        text=> sub {
          $self->logf(debug => '[ws] < %s', $_[1]);
          my ($self, $octets) = @_;
          my $data = $JSON->decode($octets) || {};
          my $cid = $data->{cid};
          if (!$cid) {
            $self->logf(debug => "Invalid message:\n" . $octets . "\nerr:" . $JSON->error);
            return;
          }

          return $self->_handle_socket_data($cid => $data) if $allowed{$cid};
          $self->send_partial('event/server_message', message => "Not allowed to subscribe to $cid", status => 403);
          $self->finish;
        }
      );
    }
  );
}

sub _handle_socket_data {
  my ($self, $cid, $data) = @_;
  my $cmd = $self->parse_command($data);
  if ($cmd) {
    $self->logf(debug => '[connection:%s:to_server] < %s', $cid, $data->{cmd});
    $self->redis->publish("connection:$cid:to_server", $cmd);
  }
}

sub _subscribe_to_server_messages {
  my ($self, $cid) = @_;
  my $sub = $self->redis->subscribe("connection:$cid:from_server");

  Scalar::Util::weaken($self);
  $sub->on(
    message => sub {
      my ($redis, $message) = @_;
      my $data = $self->format_conversation([$message])->[0];
      $self->logf(debug => '[connection:%s:from_server] > %s', $cid, $message);
      $self->send_partial('event/'.$data->{event},%$data);
    }
  );

  $self->stash("sub_$cid" => $sub);
  $self->on(finish => sub { $self->stash("sub_$cid" => undef) });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
