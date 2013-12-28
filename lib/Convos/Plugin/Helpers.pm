package Convos::Plugin::Helpers;

=head1 NAME

Convos::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Convos::Core::Util qw( format_time id_as);
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use URI::Find;

=head1 HELPERS

=head2 avatar

Used to insert an image tag.

=cut

sub avatar {
  my($self, $avatar, @args) = @_;
  my $id = join '@', @$avatar{qw( user host )};

  $self->image($self->url_for(avatar => { id => $id }), @args);
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

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->zrevrange("user:$login:conversations", 0, -1, 'WITHSCORES', $delay->begin);
    },
    sub {
      my ($delay, $conversation_list) = @_;
      my $i = 0;

      while ($i < @$conversation_list) {
        my $name = $conversation_list->[$i];
        my $timestamp = splice @$conversation_list, ($i + 1), 1;
        my ($server, $target) = id_as $name;

        $target ||= '';
        $conversation_list->[$i] = {
          server => $server,
          is_channel => $target =~ /^[#&]/ ? 1 : 0,
          target => $target,
          timestamp => $timestamp,
        };

        $self->redis->zcount("user:$login:connection:$server:$target:msg", $timestamp, '+inf', $delay->begin);
        $i++;
      }

      $delay->begin->(undef, $conversation_list);
      $self->stash(conversation_list => $conversation_list);
    },
    sub {
      my ($delay, @unread_count) = @_;
      my $conversation_list = pop @unread_count;

      for my $c (@$conversation_list) {
        $c->{unread} = shift @unread_count || 0;
      }

      return $self->$cb($conversation_list) if $cb;
      return $self->render;
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
  my($c, $conversation, $cb) = @_;
  my $delay = Mojo::IOLoop->delay;

  while (my $message = $conversation->()) {
    $message->{embed} = '';
    $message->{uuid} ||= '';
    $message->{message} = _parse_message($c, $message, $delay) if defined $message->{message};

    push @{ $c->{conversation} }, $message;
  }

  $c->{format_conversation}++;

  $delay->once(finish => sub {
    $c->$cb(delete $c->{conversation} || []) unless --$c->{format_conversation};
  });

  $delay->begin->();    # need to do at least one step
}

sub _parse_message {
  my($c, $message, $delay) = @_;
  my $last = 0;
  my @chunks;

  $message->{highlight} ||= 0;

  # http://www.mirc.com/colors.html
  $message->{message} =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $message->{message} =~ s/[\x00-\x1f]//g;

  my $finder=URI::Find->new(sub { 
      my $url=Mojo::Util::html_unescape(shift.''); 
      $c->link_to($url, $url, target => '_blank'); });
  my $msg=Mojo::Util::xml_escape($message->{message});
  $finder->find(\$msg);
  return $msg;
}

=head2 logf

See L<Convos::Core::Util/logf>.

=head2 redis

Returns a L<Mojo::Redis> object.

=cut

sub redis {
  my $c = shift;

  $c->stash->{redis} ||= do {
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
      return $self->respond_to(json => {json => $self->stash('notification_list')}, html => sub { shift->render },);
    },
  );
}

=head2 send_partial

Will render "partial" and L<send|Mojolicious::Controller/send> the result.

=cut

sub send_partial {
  my $c = shift;

  eval {
    $c->send($c->render(@_, partial => 1)->to_string)
  } or do {
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
  my ($self,$login)=@_;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $redis->zrevrange("user:$login:conversations", 0, 1, $delay->begin);
    },
    sub {
      my($delay, $names) = @_;

      if($names and $names->[0]) {
        if(my($server, $target) = id_as $names->[0]) {
          return $self->redirect_to('view', server => $server, target => $target);
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

  $app->helper(avatar => \&avatar);
  $app->helper(format_conversation => \&format_conversation);
  $app->helper(conversation_list => \&conversation_list);
  $app->helper(logf                => \&Convos::Core::Util::logf);
  $app->helper(format_time => sub { shift; format_time(@_); });
  $app->helper(notification_list => \&notification_list);
  $app->helper(redis => \&redis);
  $app->helper(as_id => sub { shift; Convos::Core::Util::as_id(@_) });
  $app->helper(id_as => sub { shift; Convos::Core::Util::id_as(@_) });
  $app->helper(send_partial => \&send_partial);
  $app->helper(timestamp_span => \&timestamp_span);
  $app->helper(redirect_last => \&redirect_last);
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
