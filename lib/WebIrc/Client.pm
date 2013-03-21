package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Unicode::UTF8;
no warnings "utf8";
use Mojo::Util 'xml_escape';
use List::MoreUtils qw/ zip /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $N_MESSAGES = 50;
my $JSON       = Mojo::JSON->new;

=head1 METHODS

=head2 route

Route to last seen IRC channel.

=cut

sub route {
  my $self = shift->render_later;
  my $uid  = $self->session('uid');
  my ($connections, $channels);

  return $self->render(template => 'index') unless $uid;
  return $self->redirect_to($self->session('current_active')) if $self->session('current_active');

  # do we need weaken here? I don't think so, since the CODE refs are going
  # out of scope once it has completed...
  Mojo::IOLoop->delay(
    sub {
      $self->redis->smembers("user:$uid:connections", shift->begin);
    },
    sub {
      $connections = pop;
      $self->redirect_to($self->url_for('settings')) unless @$connections;
      $self->redis->smembers('connection:' . $connections->[0] . ':channels', shift->begin);
    },
    sub {
      $channels = pop;
      return $self->redirect_to($self->url_for('channel.view', cid => $connections->[0], target => $channels->[0]))
        if @$channels;
      $self->redirect_to($self->url_for('settings'));
    }
  );
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self   = shift->render_later;
  my $uid    = $self->session('uid');
  my @keys   = qw/ nick current_nick host /;
  my $target = $self->param('target');
  my $cid    = $self->param('cid');
  my $connections;

  $self->session('current_active' => $self->url_for);

  Mojo::IOLoop->delay(
    sub {
      $self->redis->sismember("user:$uid:connections", $cid, $_[0]->begin);
    },
    sub {
      my ($delay, $conn) = @_;
      return $self->render_not_found if (!$conn);
      $self->redis->smembers("user:$uid:connections", $_[0]->begin);
    },
    sub {
      $connections = $_[1];
      $self->redis->execute((map { [hmget => "connection:$_" => @keys] } @$connections), $_[0]->begin,);
    },
    sub {
      my ($delay, @info) = @_;
      my $cb = $delay->begin;

      for my $info (@info) {
        $info = {zip @keys, @$info};
        $info->{id} = shift @$connections;
        $self->redis->execute(
          ['smembers', "connection:" . $info->{id} . ':channels'],
          ['smembers', "connection:" . $info->{id} . ':conversations'],
          sub {
            my ($redis, $channels, $conversations) = @_;
            $info->{channels}      = $channels;
            $info->{conversations} = $conversations;
          }
        );

      }

      @info = sort { $a->{host} cmp $b->{host} } @info;

      my ($conn) = grep { $_->{cid} && $cid == $_->{cid} } @info;
      $self->stash(connections => \@info, connection_id => $cid, target => $target,);

      # FIXME: Should be using last seen tz and default to -inf
      my $redis_key = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";
      $self->redis->zrevrangebyscore($redis_key, "+inf" => "-inf", "withscores", "limit" => 0, $N_MESSAGES, $cb,);
    },
    sub {
      $self->stash(conversation => $self->_format_conversation($_[1]));
      unless ($target) {
        return $self->render(nicks => [], template => 'client/conversation', layout => undef) if $self->req->is_xhr;
        return $self->render(nicks => []);
      }
      $self->redis->smembers("connection:$cid:$target:nicks", $_[0]->begin);
    },
    sub {
      return $self->render(nicks => $_[1], template => 'client/conversation', layout => undef) if $self->req->is_xhr;
      $self->render(nicks => $_[1]);

    }
  );
}

=head2 history

=cut

sub history {
  my $self   = shift->render_later;
  my $page   = $self->param('page');
  my $cid    = $self->param('cid');
  my $target = $self->param('target') // '';

  unless ($page and $cid) {
    return $self->render_exception('Missing parameters');    # TODO: Need to have a better error message?
  }

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->hget("connection:$cid", 'current_nick', $delay->begin);
    },
    sub {
      my ($delay, $nick) = @_;
      $self->stash(nick => $nick);
      my $offset = ($page - 1) * $N_MESSAGES;

      my $redis_key = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";

      $self->redis->zrevrangebyscore(
        $redis_key,
        "+inf" => "-inf",
        "withscores",
        "limit" => $offset,
        $offset + $N_MESSAGES, $delay->begin,
      );
    },
    sub {
      $self->render(
        layout        => undef,
        connection_id => $cid,
        connections   => [],
        nicks         => [],
        conversation  => $self->_format_conversation($_[1]),
        nick          => $self->stash('nick'),
        target        => $target,
        template      => 'client/conversation',
      );
    }
  );
}

sub _format_conversation {
  my ($self, $conversation) = @_;
  my $nick     = $self->stash('nick');
  my $messages = [];

  for (my $i = 0; $i < @$conversation; $i = $i + 2) {
    my $message = $JSON->decode($conversation->[$i]);
    unless (ref $message) {
      $self->logf(debug =>'Unable to parse raw message: ' . $conversation->[$i]);
      next;
    }
    $nick //= '[server]';
    $message->{message} =~ s!\b(\w{2,5}://\S+)!<a href="$1" target="_blank">$1</a>!gi;

    unshift @$messages, $message;
  }

  return $messages;
}

=head2 socket

TODO

=cut

sub socket {
  my $self = shift;
  my $uid  = $self->session('uid');

  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

  $self->render_later;
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
      my $data = $JSON->decode($message) || {};
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
