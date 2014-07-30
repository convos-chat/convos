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
  my $self  = shift;
  my $login = $self->session('login');

  if ($login) {
    $self->redirect_last($login);
  }
  else {
    $self->redis->scard(
      'users',
      sub {
        my ($redis, $n) = @_;
        $self->redirect_to($n ? 'login' : 'register');
      }
    );
  }
}

=head2 conversation

Used to render the main IRC client conversation.

=cut

sub conversation {
  my $self      = shift;
  my $prev_name = $self->session('name') || '';
  my $login     = $self->session('login');
  my $network   = $self->stash('network');
  my $target    = $self->stash('target') || '';
  my $name      = as_id $network, $target;
  my $redis     = $self->redis;
  my $full_page = $self->stash('full_page');
  my @rearrange = ([zscore => "user:$login:conversations", $name]);

  if ($prev_name and $prev_name ne $name) {
    push @rearrange, [zscore => "user:$login:conversations", $prev_name];
  }

  $self->session(name => $target ? $name : '');
  $self->stash(from_archive => 0, target => $target, state => 'connected');

  $self->delay(
    sub {
      my ($delay) = @_;
      $redis->execute(@rearrange, $delay->begin);    # make sure conversations exists before doing zadd
    },
    sub {
      my ($delay, @score) = @_;
      my $time = time;

      if ($target and !$score[0]) {                  # no such conversation
        return $delay->begin(0)->([$login, 'connected']) if $self->param('from');
        return $self->stash(layout => 'tactile')->render_not_found;
      }
      if (!$target) {
        $self->stash(sidebar => 'convos');
      }
      if ($network eq 'convos') {
        return $delay->begin(0)->([$login, 'connected']);
      }

      $redis->hmget("user:$login:connection:$network", qw( current_nick nick state ), $delay->begin);
      $redis->zadd("user:$login:conversations", $time + 0.001, $name)      if $score[0];
      $redis->zadd("user:$login:conversations", $time,         $prev_name) if $score[1];
    },
    sub {
      my $delay        = shift;
      my $current_nick = shift @{$_[0]};
      my $wanted_nick  = shift @{$_[0]};
      my $state        = shift @{$_[0]};

      if (length $self->param('nid')) {
        $self->_modify_notification($self->param('nid'), read => 1, sub { });
      }

      $state ||= 'disconnected';
      $self->stash(current_nick => $current_nick || $wanted_nick, state => $state);
      $self->_conversation($delay->begin);
    },
    sub {
      my ($delay, $conversation) = @_;

      $self->conversation_list($delay->begin);
      $self->notification_list($delay->begin) if $full_page;
      $self->stash(conversation => $conversation || []);
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
  my $self = shift;
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
  my $self  = shift;
  my $login = $self->session('login');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->lrange("user:$login:notifications", 0, 100, $delay->begin);
    },
    sub {
      my ($delay, $notification_list) = @_;
      my $i = 0;

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

=head2 notifications

Render L<Convos::Plugin::Helpers/notification_list> as HTML or JSON.

=cut

sub notifications {
  my $self = shift;

  $self->delay(
    sub {
      my ($delay) = @_;

      $self->notification_list($delay->begin);
      $self->_modify_notification($self->param('nid'), read => 1, $delay->begin) if length $self->param('nid');
    },
    sub {
      my ($delay, $notification_list) = @_;

      $self->respond_to(json => {json => $notification_list}, html => {template => 'sidebar/notification_list'},);
    },
  );
}

sub _conversation {
  my ($self, $cb) = @_;
  my $login   = $self->session('login');
  my $network = $self->stash('network');
  my $target  = $self->stash('target');
  my $key     = $target ? "user:$login:connection:$network:$target:msg" : "user:$login:connection:$network:msg";

  if (my $to = $self->param('to')) {    # to a timestamp
    $self->stash(from_archive => 1);
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
    $self->stash(from_archive => 1);
    $self->redis->zrangebyscore(
      $key => $from,
      '+inf',
      'WITHSCORES',
      LIMIT => 0,
      $N_MESSAGES + 1,
      sub {
        my $list = pop || [];
        $self->stash(got_more => @$list / 2 > $N_MESSAGES);
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
