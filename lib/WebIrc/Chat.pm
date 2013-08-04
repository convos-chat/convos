package WebIrc::Chat;

=head1 NAME

WebIrc::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

my $JSON = Mojo::JSON->new;
my %COMMANDS; %COMMANDS = (
  j     => \'join',
  join  => 'JOIN',
  t     => \'topic',
  topic => sub { my $dom = pop; "TOPIC $dom->{target}" . ($dom->{cmd} ? ' :' . $dom->{cmd} : '') },
  w     => \'whois',
  whois => 'WHOIS',
  nick  => 'NICK',
  names => sub { my $dom = pop; "NAMES " . ($dom->{cmd} || $dom->{target}) },
  me   => sub { my $dom = pop; "PRIVMSG $dom->{target} :\x{1}ACTION $dom->{cmd}\x{1}" },
  msg  => sub { my $dom = pop; $dom->{cmd} =~ s!^(\w+)\s*!!; "PRIVMSG $1 :$dom->{cmd}" },
  part => sub { my $dom = pop; "PART " . ($dom->{cmd} || $dom->{target}) },
  query=> sub {
    my ($self, $dom) = @_;
    my $uid = $self->session('uid');
    my $target = $dom->{cmd} || $dom->{target};
    my $id = $self->as_id($dom->{cid}, $target);

    $self->redis->zrem("user:$uid:conversations", $id, sub {
      $self->send_partial('event/add_conversation', %$dom, target => $target);
    });
    return;
  },
  close => sub {
    my ($self, $dom) = @_;
    my $uid = $self->session('uid');
    my $target = $dom->{cmd} || $dom->{target};
    my $id = $self->as_id($dom->{cid}, $target);

    return "PART $target" if $target =~ /^#/;
    $self->redis->zrem("user:$uid:conversations", $id, sub {
      $self->send_partial('event/remove_conversation', %$dom, target => $target);
    });
    return;
  },
  reconnect => sub {
    my ($self, $dom) = @_;
    $self->redis->publish('core:control', "restart:$dom->{cid}");
    return;
  },
  help => sub {
    my ($self, $dom) = @_;
    $self->send_partial('event/help');
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
        message => sub {
          $self->logf(debug => '[ws] < %s', $_[1]);
          my ($self, $octets) = @_;
          my $dom = Mojo::DOM->new($octets)->at('div');
          my($cid, $target) = map { delete $dom->{$_} || '' } qw/ data-cid data-target /;

          @$dom{qw/ cid target /} = ($cid, $target);

          if($cid and $allowed{$cid}) {
            $self->_handle_socket_data($dom);
          }
          else {
            $self->send_partial(
              'event/server_message',
              cid => '',
              message => "Not allowed to subscribe to $cid",
              status => 403,
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
  my $cmd = Mojo::Util::html_unescape($dom->text(0));
  my $key = "connection:@{[$dom->{cid}]}:to_server";
  my $uid = $self->session('uid');

  $self->logf(debug => '[%s] < %s', $key, $cmd);

  if ($cmd =~ s!^/(\w+)\s*!!) {
    if (my $irc_cmd = $COMMANDS{$1}) {
      $dom->{cmd} = $cmd =~ s/\s+$//r; # / st2 format hack
      $irc_cmd = $COMMANDS{$$irc_cmd} if ref $irc_cmd eq 'SCALAR';
      $cmd = ref $irc_cmd eq 'CODE' ? $self->$irc_cmd($dom) : "$irc_cmd $cmd";
    }
    else {
      $self->send_partial('event/wirc_notice', message => 'Unknown command. Type /help to see available commands.');
      $cmd = undef;
    }
  }
  elsif($dom->{target}) {
    $cmd = "PRIVMSG $dom->{target} :$cmd";
  }
  else {
    $cmd = undef;
  }

  if(defined $cmd) {
    $self->redis->publish($key => $cmd);
    if($dom->{'data-history'}) {
      $self->redis->rpush("user:$uid:cmd_history", $dom->text(0));
      $self->redis->ltrim("user:$uid:cmd_history", -30, -1);
    }
  }
}

sub _subscribe_to_server_messages {
  my ($self, $cid) = @_;
  my $sub = $self->redis->subscribe("connection:$cid:from_server");

  Scalar::Util::weaken($self);
  $sub->timeout(0);
  $sub->on(
    error => sub { $self->finish; }
  );
  $sub->on(
    message => sub {
      my $redis = shift;
      my @messages = (shift);

      $self->logf(debug => '[connection:%s:from_server] > %s', $cid, $messages[0]);
      $self->format_conversation(
        sub { $JSON->decode(shift @messages) },
        sub {
          my($self, $messages) = @_;
          $self->send_partial("event/$messages->[0]{event}", target => '', %{ $messages->[0] });
        },
      );
    }
  );

  $self->stash("sub_$cid" => $sub);
  $self->on(finish => sub {
    $self or return; # global destruction
    $self->stash("sub_$cid" => undef);
  });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
