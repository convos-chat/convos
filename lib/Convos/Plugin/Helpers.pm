package Convos::Plugin::Helpers;

=head1 NAME

Convos::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON 'j';
use Convos::Core::Util qw( format_time id_as);
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use URI::Find;

=head1 HELPERS

=head2 active_class

Will add "active" class to a link based on url

=cut

sub active_class {
  my $c   = shift;
  my $url = $c->url_for(@_);

  return ($url, $url eq $c->req->url->path ? (class => 'active') : (),);
}

=head2 avatar

Used to insert an image tag.

=cut

sub avatar {
  my ($self, $avatar, @args) = @_;
  my $id = join '@', @$avatar{qw( user host )};

  $self->image($self->url_for(avatar => {id => $id}), @args);
}

=head2 id_as

See L<Convos::Core::Util/id_as>.

=head2 as_id

See L<Convos::Core::Util/as_id>.

=head2 connection_list

Render the connections for a given user.

=cut

sub connection_list {
  my ($self, $cb) = @_;
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->smembers("user:$login:connections", $_[0]->begin);
    },
    sub {
      my ($delay, $connections) = @_;

      $self->stash(connections => $connections || []);
      $self->$cb;
    },
  );
}

=head2 conversation_list

Will render the conversation list for all conversations.

=cut

sub conversation_list {
  my ($self, $cb) = @_;
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
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
      my ($delay, @unread_count) = @_;
      my $conversation_list = pop @unread_count;

      for my $c (@$conversation_list) {
        $c->{unread} = shift @unread_count || 0;
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
    $message->{uuid} ||= '';

    defined $message->{message} and _parse_message($c, $message, $delay);
    push @{$c->{conversation}}, $message;
  }

  $c->{format_conversation}++;

  $delay->once(
    finish => sub {
      $c->$cb(delete $c->{conversation} || []) unless --$c->{format_conversation};
    }
  );

  $delay->begin->();    # need to do at least one step
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
      $c->link_to($url, $url, target => '_blank', class => 'embed');
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
    my $log = $c->app->log;
    my $redis = Mojo::Redis->new(server => $c->config->{redis});

    $redis->on(
      error => sub {
        my ($redis, $err) = @_;
        $log->error('[REDIS ERROR] ' . $err);
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

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      my $n = $self->param('notification');

      if (defined $n) {
        $self->_modify_notification($n, read => 1, $delay->begin);
      }
      else {
        $delay->begin->();
      }
    },
    sub {
      my ($delay, $modified) = @_;
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

      $self->stash(notification_list => $notification_list, n_notifications => $n_notifications,);

      return $self->$cb($notification_list) if $cb;
      return $self->respond_to(
        json => {json     => $self->stash('notification_list')},
        html => {template => 'client/notification_list'},
      );
    },
  );
}

=head2 send_partial

Will render "partial" and L<send|Mojolicious::Controller/send> the result.

=cut

sub send_partial {
  my $c = shift;

  eval { $c->send($c->render(@_, partial => 1)->to_string) } or do {
    $c->app->log->error($@);
  };
}

=head2 timestamp_span

Returns a "E<lt>span>" tag with a timestamp.

=cut

sub timestamp_span {
  my ($c, $timestamp) = @_;

  return $c->tag(
    'span',
    class => 'timestamp',
    title => format_time($timestamp, '%e. %B'),
    format_time($timestamp, '%e. %b %H:%M:%S')
  );
}

=head2 redirect_last

Redirect to the last visited channel for $login. Falls back to settings.

=cut

sub redirect_last {
  my ($self, $login) = @_;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
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
    }
  );
}

=head1 METHODS

=head2 register

Will register the L</HELPERS> above.

=cut

sub register {
  my ($self, $app) = @_;

  $app->helper(active_class        => \&active_class);
  $app->helper(avatar              => \&avatar);
  $app->helper(format_conversation => \&format_conversation);
  $app->helper(connection_list     => \&connection_list);
  $app->helper(conversation_list   => \&conversation_list);
  $app->helper(logf                => \&Convos::Core::Util::logf);
  $app->helper(format_time => sub { shift; format_time(@_); });
  $app->helper(notification_list => \&notification_list);
  $app->helper(redis             => \&redis);
  $app->helper(as_id => sub { shift; Convos::Core::Util::as_id(@_) });
  $app->helper(id_as => sub { shift; Convos::Core::Util::id_as(@_) });
  $app->helper(send_partial   => \&send_partial);
  $app->helper(timestamp_span => \&timestamp_span);
  $app->helper(redirect_last  => \&redirect_last);
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
