package Convos::Client;

=head1 NAME

Convos::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'j';
use Convos::Core::Util qw/ as_id id_as /;
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;

my $N_MESSAGES = $ENV{N_MESSAGES} || 30;

=head1 METHODS

=head2 route

Route to last seen IRC conversation.

=cut

sub route {
  my $self = shift->render_later;
  my $login = $self->session('login');

  if($login) {
    $self->redirect_last($login);
  }
  else {
    $self->redis->scard('users', sub {
      my($redis, $n) = @_;
      $self->redirect_to($n ? 'login' : 'register');
    });
  }
}

=head2 convos

Will render all server logs.

=cut

sub convos {
  my $self = shift->render_later;

  $self->stash(server => 'convos', sidebar => 'convos', template => 'client/view');
  $self->connection_list(\&view);
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self        = shift->render_later;
  my $prev_name   = $self->session('name') || '';
  my $login       = $self->session('login');
  my $server      = $self->stash('server');
  my $target      = $self->stash('target') || '';
  my $name        = as_id $server, $target;
  my $xhr         = $self->req->is_xhr ? 1 : 0;
  my $redis       = $self->redis;
  my @rearrange   = ([ zscore => "user:$login:conversations", $name ]);

  if($prev_name and $prev_name ne $name) {
    push @rearrange, [ zscore => "user:$login:conversations", $prev_name ];
  }
  if($xhr) {
    $self->stash(layout => undef);
  }

  $self->stash(target => $target, body_class => 'without-sidebar', xhr => $xhr);
  $self->session(name => $target ? $name : '');

  if(!$target or $target =~ /^[#&]/) {
    $self->stash->{body_class} = 'with-sidebar';
  }

  $self->stash->{body_class} .= ' '. ($server eq 'convos' ? 'convos' : 'chat');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->execute(@rearrange, $delay->begin); # make sure conversations exists before doing zadd
    },
    sub {
      my ($delay, @score) = @_;
      my $time = time;

      return $self->route if $target and not grep { $_ } @score; # no such conversation
      return $delay->begin(0)->([ $login, 'connected' ]) if $server eq 'convos';

      $redis->hmget("user:$login:connection:$server", qw( nick state ), $delay->begin);
      $redis->zadd("user:$login:conversations", $time, $name) if $score[0];
      $redis->zadd("user:$login:conversations", $time - 0.001, $prev_name) if $score[1];
    },
    sub {
      my ($delay, $nick_state) = @_;

      if(!$nick_state or !$nick_state->[0]) {
        return $self->route;
      }
      if(defined $self->param('notification')) {
        $self->_modify_notification($self->param('notification'), read => 1, sub {});
      }

      $nick_state->[1] ||= 'disconnected';
      $self->stash(nick => $nick_state->[0], state => $nick_state->[1]);
      $self->stash->{sidebar} ||= 'server' unless $target;
      $self->_conversation($delay->begin);
      $delay->begin->();
    },
    sub {
      my ($delay, $conversation) = @_;

      unless($xhr) {
        $self->conversation_list($delay->begin);
        $self->notification_list($delay->begin);
      }

      $self->stash(conversation => $conversation) if $conversation;
      $delay->begin->(0);
    },
    sub {
      $self->render;
    },
  );
}

=head2 command_history

Render the command history.

=cut

sub command_history {
  my $self = shift->render_later;
  my $login = $self->session('login') || '';

  $self->redis->lrange(
    "user:$login:cmd_history",
    0, -1,
    sub {
      $self->render(json => $_[1] || []);
    }
  );
}

=head2 clear_notifications

Will mark all notifications as read.

=cut

sub clear_notifications {
  my $self  = shift->render_later;
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->lrange("user:$login:notifications", 0, 100, $delay->begin);
    },
    sub {
      my ($delay, $notification_list) = @_;
      my $n_notifications = 0;
      my $i               = 0;

      while ($i < @$notification_list) {
        my $notification = j $notification_list->[$i];
        $notification->{read}++;
        $self->redis->lset("user:$login:notifications", $i, j $notification);
        $i++;
      }

      $self->render(json => {cleared => $i});
    }
  );
}

sub _conversation {
  my ($self, $cb) = @_;
  my $login  = $self->session('login');
  my $server = $self->stash('server');
  my $target = $self->stash('target');
  my $key    = $target ? "user:$login:connection:$server:$target:msg" : "user:$login:connection:$server:msg";

  if (my $to = $self->param('to')) {    # to a timestamp
    $self->redis->zrevrangebyscore(
      $key => $to,
      '-inf',
      'WITHSCORES',
      LIMIT => 0,
      $N_MESSAGES,
      sub {
        my $list = pop || [];
        $self->format_conversation(
          sub {
            my $timestamp = pop @$list;
            my $message = j(pop @$list) or return;
            $message->{timestamp} = $timestamp;
            $message;
          },
          $cb
        );
      }
    );
  }
  elsif (my $from = $self->param('from')) {    # from at timestamp
    $self->redis->zrangebyscore(
      $key => $from,
      '+inf',
      'WITHSCORES',
      LIMIT => 0,
      $N_MESSAGES + 1,
      sub {
        my $list = pop || [];
        $self->stash(got_more => @$list / 2 > $N_MESSAGES);
        $self->stash(body_class => 'historic') if $self->stash('got_more');
        $self->format_conversation(
          sub {
            my $current = shift @$list or return;
            my $message = j $current;
            @$list or return;    # skip the last
            $message->{timestamp} = shift @$list;
            $message;
          },
          $cb,
        );
      }
    );
  }
  else {                         # default
    $self->redis->zcard(
      $key,
      sub {
        my ($redis, $end) = @_;
        my $start = $end > $N_MESSAGES ? $end - $N_MESSAGES : 0;
        $redis->zrange(
          $key => $start,
          $end,
          'WITHSCORES',
          sub {
            my $list = pop || [];
            $self->format_conversation(
              sub {
                my $message = j(shift @$list) or return;
                $message->{timestamp} = shift @$list;
                $message;
              },
              $cb,
            );
          }
        );
      }
    );
  }
}

sub _modify_notification {
  my ($self, $id, $key, $value, $cb) = @_;
  my $login     = $self->session('login');
  my $redis_key = "user:$login:notifications";

  $self->redis->lindex(
    $redis_key,
    $id,
    sub {
      my $redis = shift;
      my $notification = shift or return $redis->$cb(0);
      $notification = j $notification;
      $notification->{$key} = $value;
      $redis->lset($redis_key, $id, j($notification), $cb);
    }
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
