package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $N_MESSAGES = 50;

=head1 METHODS

=head2 route

Route to last seen IRC channel.

=cut

sub route {
  my $self = shift->render_later;
  my $uid  = $self->session('uid');
  my $settings = sub { $self->redirect_to($self->url_for('settings')) };

  if(!$uid) {
    $self->render('index');
  }
  else {
    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $self->redis->get("user:$uid:cid_target", $delay->begin);
      },
      sub {
        my($delay, $cid_target) = @_;
        if(my($cid, $target) = $self->id_as($cid_target || '')) {
          $self->redis->del("user:$uid:cid_target"); # prevent loop on invalid cid_target
          $self->redirect_to($self->url_for('channel.view', cid => $cid, target => $target));
        }
        else {
          $self->redis->smembers("user:$uid:connections", $delay->begin);
        }
      },
      sub {
        my($delay, $connections) = @_;
        return $settings->() unless $connections->[0];
        $self->redis->smembers("connection:$connections->[0]:channels", $delay->begin);
        $delay->begin->(undef, $connections->[0]);
      },
      sub {
        my($delay, $channels, $cid) = @_;
        $self->redirect_to(
          $self->url_for('channel.view', cid => $cid, target => $channels->[0])
        );
      }
    );
  }
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self   = shift->render_later;
  my $redis  = $self->redis;
  my $uid    = $self->session('uid');
  my $cid    = $self->stash('cid');
  my $target = $self->stash('target') || '';
  my $key    = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";
  my $current_nick;

  Mojo::IOLoop->delay(
    $self->_check_if_uid_own_cid($cid),
    sub {
      my($delay) = @_;

      $redis->lrem("user:$uid:conversations", 0, "$cid:$target", $delay->begin);
      $redis->zrem("user:$uid:important_conversations", "$cid:$target");
    },
    sub {
      my($delay, $part_of_conversation) = @_;
      $part_of_conversation or return $self->redirect_to('index');

      $redis->hgetall("connection:$cid", $delay->begin);
      $redis->zcard($key, $delay->begin);
      $self->_conversation_list($delay->begin);
      $redis->set("user:$uid:cid_target", $self->as_id($cid, $target));
      $redis->lpush("user:$uid:conversations", "$cid:$target");
    },
    sub {
      my($delay, $connection, $length) = @_;
      my $end = $length > $N_MESSAGES ? $N_MESSAGES : $length;

      $self->stash(%$connection);
      $redis->zrevrange($key => -$end, -1, $delay->begin);
    },
    sub {
      my($delay, $conversation) = @_;

      $self->format_conversation($conversation, $delay->begin);
    },
    sub {
      my($delay, $conversation) = @_;

      $self->stash(
        conversation => $conversation,
      );

      return $self->render('client/conversation', layout => undef) if $self->req->is_xhr;
      return $self->render;
    },
  );
}

=head2 conversation_list

Will render the connection list for a given connection id.

=cut

sub conversation_list {
  my $self = shift->render_later;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->_conversation_list($delay->begin);
    },
    sub {
      my($delay) = @_;
      $self->render('client/conversation_list');
    },
  );
}

=head2 history

Used to render the previous messages in a conversation, suitable for the IRC
client view.

=cut

sub history {
  my $self = shift->render_later;
  my $offset = $self->stash('offset');
  my($cid, $target) = $self->id_as($self->stash('target'));
  my $key = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";

  unless($offset and $cid) {
    return $self->render_exception('Missing parameters'); # TODO: Need to have a better error message?
  }

  $target ||= '';
  $self->stash(target => $target, cid => $cid, nick => '', nicks => []);
  Mojo::IOLoop->delay(
    $self->_check_if_uid_own_cid($cid),
    sub {
      my($delay) = @_;
      $self->redis->zrevrangebyscore($key => $offset, '-inf', limit => 0 => $N_MESSAGES, $delay->begin);
    },
    sub {
      my($delay, $conversation) = @_;
      $self->format_conversation($conversation, $delay->begin);
    },
    sub {
      my($delay, $conversation) = @_;
      $self->render('client/conversation', conversation => $conversation);
    },
  );
}

sub _check_if_uid_own_cid {
  my($self, $cid) = @_;
  my $uid = $self->session('uid') // -1;

  sub {
    my($delay) = @_;
    $self->redis->sismember("user:$uid:connections", $cid, $delay->begin);
  },
  sub {
    my($delay, $is_owner) = @_;
    return $delay->begin->() if $is_owner;
    $self->redis->del("user:$uid:cid_target");
    $self->route;
  },
}

sub _conversation_list {
  my($self, $cb) = @_;
  my $redis = $self->redis;
  my $uid = $self->session('uid');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $redis->smembers("user:$uid:connections", $delay->begin);
    },
    sub {
      my($delay, $cids) = @_;
      $self->stash(cids => $cids);
      $redis->execute((map { [ hget => "connection:$_", "host" ] } @$cids), $delay->begin);
    },
    sub {
      my($delay, @hosts) = @_;
      my $cids = $self->stash('cids');
      $self->stash(servers => { map { $_ => shift @hosts || '' } @$cids });
      $redis->zrevrangebyscore("user:$uid:important_conversations", '+inf', '-inf', 'WITHSCORES', $delay->begin);
    },
    sub {
      my($delay, $important_conversations) = @_;
      my $n_notifications = 0;
      my $i = 0;

      while($i < @$important_conversations) {
        my($score) = splice @$important_conversations, ($i + 1), 1;
        $n_notifications += $score;
        $important_conversations->[$i] =~ /^(\d+):(.*)/;
        $important_conversations->[$i] = {
          cid => $1,
          id => $important_conversations->[$i],
          target => $2,
          score => $score,
        };
        $i++;
      }

      $self->stash(
        important_conversations => $important_conversations,
        n_notifications => $n_notifications,
      );

      $redis->lrange("user:$uid:conversations", 0, -1, $delay->begin);
    },
    sub {
      my($delay, $conversations) = @_;
      my $i = 0;

      for my $item (@$conversations) {
        $item =~ /^(\d+):(.*)/;
        $item = { cid => $1, id => $item, target => $2 };
        $item->{title}
          = $i++                    ? "View conversation with $item->{target}"
          : $item->{target} =~ /^#/ ? "(Topic is not loaded)"
          :                           "Private conversation"
          ;
      }

      $self->stash(conversations => $conversations);
      $cb->();
    },
  );
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
