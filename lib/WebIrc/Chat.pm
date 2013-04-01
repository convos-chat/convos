package WebIrc::Chat;

=head1 NAME

WebIrc::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';

my %COMMANDS; %COMMANDS = (
  j     => \'join',
  join  => 'JOIN',
  t     => \'topic',
  topic => sub { my $dom = pop; "TOPIC $dom->{'data-target'}" . ($dom->{cmd} ? ' :' . $dom->{cmd} : '') },
  w     => \'whois',
  whois => 'WHOIS',
  nick  => 'NICK',
  me   => sub { my $dom = pop; "PRIVMSG $dom->{'data-target'} :\x{1}ACTION $dom->{cmd}\x{1}" },
  msg  => sub { my $dom = pop; $dom->{cmd} =~ s!^(\w+)\s*!!; "PRIVMSG $1 :$dom->{cmd}" },
  part => sub { my $dom = pop; "PART " . ($dom->{cmd} || $dom->{'data-target'}) },
  query=> sub {
    my ($self, $dom) = @_;
    my $target = $dom->{cmd} || $dom->{'data-target'};
    $self->redis->sadd(
      "connection:@{[$dom->{'data-cid'}]}:conversations",
      $target,
      sub {
        my ($redis, $member) = @_;
        return unless $member;
        $self->send_partial( 'event/new_conversation', cid => $dom->{'data-cid'}, target => $target);
      }
    );
    return;
  },
  close => sub {
    my ($self, $dom) = @_;
    my $target = $dom->{cmd} || $dom->{'data-target'};
    $self->redis->sismember(
      "connection:@{[$dom->{'data-cid'}]}:conversations",
      $target,
      sub {
        my ($redis, $member) = @_;
        return unless $member;
        $self->redis->srem("connection:@{[$dom->{'data-cid'}]}:conversations", $target);
        $self->send_partial( 'event/remove_conversation', cid => $dom->{'data-cid'}, target => $target);
      }
    );
    return;
  },
  reconnect => sub {
    my ($self, $dom) = @_;
    $self->redis->publish('core:control', "restart:" . $dom->{'data-cid'});
    return;
  },
  help => sub {
    my ($self, $dom) = @_;
    $self->send_partial(
      'event/wirc_notice',
      message => "Available Commands:\n" .join(", ", sort keys %COMMANDS),
    );
    return;
  }
);

=head1 METHODS

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
        text => sub {
          $self->logf(debug => '[ws] < %s', $_[1]);
          my ($self, $octets) = @_;
          my $dom = Mojo::DOM->new($octets)->at('div');
          my $cid = $dom->{'data-cid'} // -1;

          if($allowed{$cid}) {
            $self->_handle_socket_data($dom);
          }
          else {
            $self->send_partial(
              message => "Not allowed to subscribe to $cid",
              status => 403,
              template => 'event/server_message',
              timestamp => time,
            )->finish;
          }
        }
      );
    }
  );
}

sub _handle_socket_data {
  my ($self, $dom) = @_;
  my $cmd = $dom->text(0);
  my $key = "connection:@{[$dom->{'data-cid'}]}:to_server";

  $self->logf(debug => '[%s] < %s', $key, $cmd);

  if ($cmd =~ s!^/(\w+)\s*!!) {
    if (my $irc_cmd = $COMMANDS{$1}) {
      $dom->{cmd} = $cmd;
      $irc_cmd = $COMMANDS{$$irc_cmd} if ref $irc_cmd eq 'SCALAR';
      $cmd = ref $irc_cmd eq 'CODE' ? $self->$irc_cmd($dom) : "$irc_cmd $cmd";
    }
    else {
      $cmd = $self->send_partial('event/wirc_notice', message => 'Unknown command');
    }
  }
  elsif($dom->{'data-target'}) {
    $cmd = "PRIVMSG $dom->{'data-target'} :$cmd";
  }
  else {
    $cmd = undef;
  }

  $self->redis->publish($key => $cmd) if defined $cmd;
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
