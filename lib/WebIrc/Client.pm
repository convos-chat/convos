package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use WebIrc::Core::Util qw/ as_id id_as /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $N_MESSAGES = 50;
my $JSON = Mojo::JSON->new;

=head1 METHODS

=head2 route

Route to last seen IRC conversation.

=cut

sub route {
  my $self = shift->render_later;
  my $uid  = $self->session('uid') or return $self->render('index', form => '');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->zrevrange("user:$uid:conversations", 0, 1, $delay->begin);
    },
    sub {
      my($delay, $id) = @_;

      if($id and $id->[0]) {
        if(my($cid, $target) = id_as $id->[0]) {
          return $self->redirect_to(
            $self->url_for('channel.view', cid => $cid, target => $target)
          );
        }
      }

      $self->redirect_to($self->url_for('settings')); # fallback
    }
  );
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self = shift->render_later;
  my $previous_id = $self->session('view_id') || '';
  my $uid = $self->session('uid');
  my $cid = $self->stash('cid');
  my $target = $self->stash('target');
  my $id = as_id $cid, $target;
  my $with_layout = $self->req->is_xhr ? 0 : 1;

  if($previous_id and $id ne $previous_id) {
    # make sure it's not a removed conversation before doing zadd
    $self->redis->zscore("user:$uid:conversations", $previous_id, sub {
      my($redis, $score) = @_;
      $redis->zadd("user:$uid:conversations", time - 0.001, $previous_id) if $score;
    });
  }

  $self->stash(body_class => $target =~ /^#/ ? 'with-nick-list' : 'without-nick-list');
  $self->session(view_id => $id);

  Mojo::IOLoop->delay(
    $self->_check_if_uid_own_cid($cid),
    sub {
      my($delay) = @_;
      $self->redis->zadd("user:$uid:conversations", time, $id);
      $self->redis->hgetall("connection:$cid", $delay->begin);
      $self->_modify_notification($self->param('notification'), read => 1) if defined $self->param('notification');
      $self->_conversation($delay->begin);
    },
    sub {
      my($delay, $connection, $conversation) = @_;

      if($with_layout) {
        $self->conversation_list($delay->begin);
        $self->notification_list($delay->begin);
      }

      $self->stash(%$connection, conversation => $conversation);
      $delay->begin->(0);
    },
    sub {
      return $self->render if $with_layout;
      return $self->render('client/conversation', layout => undef)
    },
  );
}

=head2 command_history

Render the command history.

=cut

sub command_history {
  my $self = shift->render_later;
  my $uid = $self->session('uid') || 0;

  $self->redis->lrange("user:$uid:cmd_history", 0, -1, sub {
    $self->render(json => $_[1] || []);
  });
}

=head2 conversation_list

Will render the conversation list for all conversations.

=cut

sub conversation_list {
  my($self, $cb) = @_;
  my $uid = $self->session('uid');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->zrevrange("user:$uid:conversations", 0, -1, 'WITHSCORES', $delay->begin);
    },
    sub {
      my($delay, $conversation_list) = @_;
      my $i = 0;

      $delay->begin(0)->($conversation_list);

      while($i < @$conversation_list) {
        my $id = $conversation_list->[$i];
        my $timestamp = splice @$conversation_list, ($i + 1), 1;
        my($cid, $target) = id_as $id;

        $target ||= '';
        $conversation_list->[$i] = {
          cid => $cid,
          id => $id,
          is_channel => $target =~ /^#/ ? 1 : 0,
          target => $target,
          timestamp => $timestamp,
        };

        $self->redis->zcount("connection:$cid:$target:msg", $timestamp, '+inf', $delay->begin);
        $i++;
      }

      $self->stash(conversation_list => $conversation_list);
    },
    sub {
      my($delay, $conversation_list, @unread_count) = @_;

      for my $c (@$conversation_list) {
        $c->{unread} = shift @unread_count || 0;
      }

      return $self->$cb($conversation_list) if $cb;
      return $self->render;
    },
  );

  $self->render_later;
}

=head2 clear_notifications

Will mark all notifications as read.

=cut

sub clear_notifications {
  my $self = shift->render_later;
  my $uid = $self->session('uid');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->lrange("user:$uid:notifications", 0, -1, $delay->begin);
    },
    sub {
      my($delay, $notification_list) = @_;
      my $n_notifications = 0;
      my $i = 0;

      while($i < @$notification_list) {
        my $notification = $JSON->decode($notification_list->[$i]);
        $notification->{read}++;
        $self->redis->lset("user:$uid:notifications", $i, $JSON->encode($notification));
        $i++;
      }

      $self->render(json => { cleared => $i });
  });
}


=head2 notification_list

Will render notifications.

=cut

sub notification_list {
  my($self, $cb) = @_;
  my $uid = $self->session('uid');
  my $key = "user:$uid:notifications";

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->lrange($key, 0, -1, $delay->begin);
    },
    sub {
      my($delay, $notification_list) = @_;
      my $n_notifications = 0;
      my %nick_seen = ();
      my $i = 0;

      while($i < @$notification_list) {
        my $n = $JSON->decode($notification_list->[$i]);
        $n->{id} = as_id @$n{qw/ cid target /};
        $n->{index} = $i;
        $n->{is_channel} = $n->{target} =~ /^#/ ? 1 : 0;

        if(!$n->{is_channel} and $nick_seen{$n->{target}}++) {
          $self->redis->lrem($key, 1, $notification_list->[$i]);
          splice @$notification_list, $i, 1, ();
          next;
        }

        $notification_list->[$i] = $n;
        $n_notifications++ unless $n->{read};
        $i++;
      }

      $self->stash(
        notification_list => $notification_list,
        n_notifications => $n_notifications,
      );

      return $self->$cb($notification_list) if $cb;
      return $self->render;
    },
  );

  $self->render_later;
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
    return $self->route;
  },
}

sub _conversation {
  my($self, $cb) = @_;
  my $uid = $self->session('uid');
  my $cid = $self->stash('cid');
  my $target = $self->stash('target');
  my $key = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";

  if(my $to = $self->param('to')) { # to a timestamp
    $self->redis->zrevrangebyscore($key => $to, '-inf', 'WITHSCORES', LIMIT => 0, $N_MESSAGES, sub {
      my $list = pop || [];
      $self->format_conversation(
        sub {
          my $timestamp = pop @$list;
          my $message = $JSON->decode(pop @$list) or return;
          $message->{timestamp} = $timestamp;
          $message;
        },
        $cb
      );
    });
  }
  elsif(my $from = $self->param('from')) { # from at timestamp
    $self->redis->zrangebyscore($key => $from, '+inf', 'WITHSCORES', LIMIT => 0, $N_MESSAGES, sub {
      my $list = pop || [];
      $self->format_conversation(
        sub {
          my $message = $JSON->decode(shift @$list) or return;
          $message->{timestamp} = shift @$list;
          $message;
        },
        $cb,
      );
    });
  }
  else { # default
    $self->redis->zcard($key, sub {
      my($redis, $end) = @_;
      my $start = $end > $N_MESSAGES ? $end - $N_MESSAGES : 0;
      $redis->zrange($key => $start, $end, 'WITHSCORES', sub {
        my $list = pop || [];
        $self->format_conversation(
          sub {
            my $message = $JSON->decode(shift @$list) or return;
            $message->{timestamp} = shift @$list;
            $message;
          },
          $cb,
        );
      });
    });
  }
}

sub _modify_notification {
  my($self, $id, $key, $value) = @_;
  my $uid = $self->session('uid');
  my $redis_key = "user:$uid:notifications";

  $self->redis->lindex($redis_key, $id, sub {
    my $redis = shift;
    my $notification = shift or return;
    $notification = $JSON->decode($notification);
    $notification->{$key} = $value;
    $redis->lset($redis_key, $id, $JSON->encode($notification));
  });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
