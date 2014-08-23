package Convos::Plugin::Helpers;

=head1 NAME

Convos::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON 'j';
use Convos::Core::Util qw( format_time id_as );
use URI::Find;
use constant DEBUG        => $ENV{CONVOS_DEBUG}        || 0;
use constant DEFAULT_URL  => $ENV{DEFAULT_AVATAR_URL}  || 'https://graph.facebook.com/%s/picture?height=40&width=40';
use constant GRAVATAR_URL => $ENV{GRAVATAR_AVATAR_URL} || 'https://gravatar.com/avatar/%s?s=40&d=retro';

=head1 HELPERS

=head2 active_class

Will add "active" class to a link based on url

=cut

sub active_class {
  my $c   = shift;
  my $url = $c->url_for(@_);

  return ($url, $url eq $c->req->url->path ? (class => 'active') : (),);
}

=head2 id_as

See L<Convos::Core::Util/id_as>.

=head2 as_id

See L<Convos::Core::Util/as_id>.

=head2 conversation_list

Will render the conversation list for all conversations.

=cut

sub conversation_list {
  my ($self, $cb) = @_;
  my $login = $self->session('login');

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->zrevrange("user:$login:conversations", 0, -1, 'WITHSCORES', $delay->begin);
      $self->redis->smembers("user:$login:connections", $delay->begin);
    },
    sub {
      my ($delay, $conversation_list, $networks) = @_;
      my $i = 0;

      while ($i < @$conversation_list) {
        my $name = $conversation_list->[$i];
        my $timestamp = splice @$conversation_list, ($i + 1), 1;
        my ($network, $target) = id_as $name;

        $target ||= '';
        $conversation_list->[$i]
          = {network => $network, is_channel => $target =~ /^[#&]/ ? 1 : 0, target => $target, timestamp => $timestamp,
          };

        $self->redis->zcount("user:$login:connection:$network:$target:msg", $timestamp, '+inf', $delay->begin);
        $i++;
      }

      $delay->begin->(undef, $conversation_list);
      $self->stash(conversation_list => $conversation_list, networks => $networks || []);
    },
    sub {
      my ($delay, @args) = @_;
      my $conversation_list = pop @args;

      for my $c (@$conversation_list) {
        $c->{unread} = shift @args || 0;
      }

      return $self->$cb($conversation_list) if $cb;
      return $self->render('client/conversation_list');
    },
  );
}

=head2 format_conversation

  $c->format_conversation(\&iterator, \&callback);

Takes a list of JSON strings and turns them into a list of hash-refs where the
"message" key contains a formatted version with HTML and such. The result will
be passed on to the C<$callback>.

=cut

sub format_conversation {
  my ($c, $conversation, $cb) = @_;
  my $delay = Mojo::IOLoop->delay;

  while (my $message = $conversation->()) {
    $message->{embed} = '';
    $message->{uuid}   ||= '';
    $message->{avatar} ||= '';

    defined $message->{message} and _parse_message($c, $message, $delay);
    defined $message->{user} and _add_avatar($c, $message, $delay);
    push @{$c->{conversation}}, $message;
  }

  $c->render_later;
  $c->{format_conversation}++;

  $delay->once(
    finish => sub {
      $c->$cb(delete $c->{conversation} || []) unless --$c->{format_conversation};
    }
  );

  $delay->begin->();    # need to do at least one step
}

sub _add_avatar {
  my ($c, $message, $delay) = @_;
  my $cache = $c->stash->{'convos.avatar_cache'} ||= {};
  my $user = $message->{user};

  $user =~ s!^~!!;      # somenick!~someuser@1.2.3.4

  if ($cache->{$user}) {
    return $message->{avatar} = $cache->{$user};
  }

  my $cb = $delay->begin;
  $c->redis->hmget(
    "user:$user",
    qw( avatar email ),
    sub {
      my ($redis, $data) = @_;
      my $id = shift @$data || shift @$data || "$user\@$message->{host}";

      if ($id =~ /\@/) {
        $message->{avatar} = sprintf GRAVATAR_URL, Mojo::Util::md5_sum($id);
      }
      elsif ($id) {
        $message->{avatar} = sprintf DEFAULT_URL, $id;
      }

      $cache->{$user} = $message->{avatar};
      $cb->();
    }
  );
}

sub _parse_message {
  my ($c, $message, $delay) = @_;

  # http://www.mirc.com/colors.html
  $message->{message} =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $message->{message} =~ s/[\x00-\x1f]//g;

  $message->{highlight} ||= 0;
  $message->{message} = Mojo::Util::xml_escape($message->{message});

  URI::Find->new(
    sub {
      my $url = Mojo::Util::html_unescape(shift . '');
      $c->link_to($url, $url, target => '_blank');
    }
  )->find(\$message->{message});
}

=head2 logf

See L<Convos::Core::Util/logf>.

=head2 redis

Returns a L<Mojo::Redis> object.

=cut

sub redis {
  my $c = shift;
  my $cache_to = $c->{tx} ? 'stash' : sub { $c->app->defaults };

  $c->$cache_to->{redis} ||= do {
    my $log   = $c->app->log;
    my $url   = $ENV{CONVOS_REDIS_URL} or die "CONVOS_REDIS_URL is not set. Run 'perldoc Convos' for details.\n";
    my $redis = Mojo::Redis->new(server => $url);

    $redis->on(
      error => sub {
        $log->error("[REDIS ERROR] $_[1]");
      }
    );

    $redis;
  };
}

=head2 notification_list

Will render notifications.

=cut

sub notification_list {
  my ($self, $cb) = @_;
  my $login = $self->session('login');
  my $key   = "user:$login:notifications";

  $self->delay(
    sub {
      my ($delay) = @_;
      $self->redis->lrange($key, 0, 20, $delay->begin);
    },
    sub {
      my ($delay, $notification_list) = @_;
      my $n_notifications = 0;
      my %nick_seen       = ();
      my $i               = 0;

      while ($i < @$notification_list) {
        my $n = j $notification_list->[$i];
        $n->{index} = $i;
        $n->{is_channel} = $n->{target} =~ /^[#&]/ ? 1 : 0;

        if (!$n->{is_channel} and $nick_seen{$n->{target}}++) {
          $self->redis->lrem($key, 1, $notification_list->[$i]);
          splice @$notification_list, $i, 1, ();
          next;
        }

        $notification_list->[$i] = $n;
        $n_notifications++ unless $n->{read};
        $i++;
      }

      $self->stash(notification_list => $notification_list, n_notifications => $n_notifications);
      $self->$cb($notification_list);
    },
  );
}

=head2 send_partial

Will render "partial" and L<send|Mojolicious::Controller/send> the result.

=cut

sub send_partial {
  my $c = shift;

  eval { $c->send($c->render_to_string(@_)->to_string) } or $c->app->log->error($@);
}

=head2 timestamp

Returns a "E<lt>div>" tag with a timestamp.

=cut

sub timestamp {
  my ($c, $timestamp) = @_;
  my $offset = $c->session('tz_offset') || 0;
  my $now    = time;
  my $format = '%e. %b %H:%M';

  $timestamp ||= $now;
  $format = '%H:%M' if $timestamp > $now - 86400;
  $timestamp += $offset * 3600;    # offset is in hours

  $c->tag(
    'div',
    class => 'timestamp',
    title => format_time($timestamp, '%e. %B %H:%M:%S'),
    format_time($timestamp, $format),
  );
}

=head2 redirect_last

Redirect to the last visited channel for $login. Falls back to settings.

=cut

sub redirect_last {
  my ($self, $login) = @_;
  my $redis = $self->redis;

  $self->delay(
    sub {
      my ($delay) = @_;
      $redis->zrevrange("user:$login:conversations", 0, 1, $delay->begin);
    },
    sub {
      my ($delay, $names) = @_;

      if ($names and $names->[0]) {
        if (my ($network, $target) = id_as $names->[0]) {
          return $self->redirect_to('view', network => $network, target => $target);
        }
      }

      $self->redirect_to('wizard');
    },
  );
}

=head1 METHODS

=head2 register

Will register the L</HELPERS> above.

=cut

sub register {
  my ($self, $app, $config) = @_;

  $app->helper(active_class        => \&active_class);
  $app->helper(format_conversation => \&format_conversation);
  $app->helper(connection_list     => \&connection_list);
  $app->helper(conversation_list   => \&conversation_list);
  $app->helper(logf                => \&Convos::Core::Util::logf);
  $app->helper(format_time => sub { shift; format_time(@_); });
  $app->helper(notification_list => \&notification_list);
  $app->helper(redis             => \&redis);
  $app->helper(as_id => sub { shift; Convos::Core::Util::as_id(@_) });
  $app->helper(id_as => sub { shift; Convos::Core::Util::id_as(@_) });
  $app->helper(send_partial  => \&send_partial);
  $app->helper(timestamp     => \&timestamp);
  $app->helper(redirect_last => \&redirect_last);
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
