package Convos::Plugin::Helpers;

=head1 NAME

Convos::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Convos::Core::Util qw(format_time);
use constant DEBUG => $ENV{CONVOS_DEBUG} ? 1 : 0;
use Convos::Core::Util qw/id_as/;

my $URL_RE = do {
  # Modified regex from RFC 3986
  no warnings; # Possible attempt to put comments
  qw!https?:(//([^/?\#\s]*))?([^?\#\s]*)(\?([^\#\s]*))?(\#(\S+))?!;
};

=head1 HELPERS

=head2 id_as

See L<Convos::Core::Util/id_as>.

=head2 as_id

See L<Convos::Core::Util/as_id>.

=head2 format_conversation

  $c->format_conversation(\&iterator, \&callback);

Takes a list of JSON strings and turns them into a list of hash-refs where the
"message" key contains a formatted version with HTML and such. The result will
be passed on to the C<$callback>.

=cut

sub format_conversation {
  my($c, $conversation, $cb) = @_;
  my $delay = Mojo::IOLoop->delay;
  my @messages;

  while (my $message = $conversation->()) {
    $message->{embed} = '';
    $message->{uuid} ||= '';
    $message->{message} = _parse_message($c, $message, $delay) if defined $message->{message};

    push @messages, $message;
  }

  $delay->once(finish => sub { $c->$cb(\@messages) });
  $delay->begin->();    # need to do at least one step
}

sub _parse_message {
  my($c, $message, $delay) = @_;
  my $last = 0;
  my @chunks;

  _message_avatar($c, $message, $delay);
  $message->{highlight} ||= 0;

  # http://www.mirc.com/colors.html
  $message->{message} =~ s/\x03\d{0,15}(,\d{0,15})?//g;
  $message->{message} =~ s/[\x00-\x1f]//g;

  while($message->{message} =~ m!($URL_RE)!g) {
    my $url = $1;
    my $now = pos $message->{message};

    push @chunks, Mojo::Util::xml_escape(substr $message->{message}, $last, $now - length($url) - $last);
    push @chunks, $c->link_to($url, $url, target => '_blank');
    $last = $now;
  }

  push @chunks, Mojo::Util::xml_escape(substr $message->{message}, $last);
  return join '', @chunks;
}

sub _message_avatar {
  my($c, $message, $delay) = @_;
  my($lookup, $cache, $cb);

  $message->{avatar} = '//gravatar.com/avatar/0000000000000000000000000000?s=40&d=retro';
  $message->{nick} or return; # do not want to insert avatar unless a user sent the message
  $message->{host} or return; # old data does not have "host" stored because of a bug
  $lookup = join '@', @$message{qw/ user host /};
  $lookup =~ s!^~!!;
  $cache = $c->stash->{"avatar.$lookup"} ||= {};

  if(!$cache->{messages}) {
    $cb = $delay->begin;
    $c->redis->get(
      "avatar:$lookup",
      sub {
        my $avatar = $_[1] || $lookup;

        delete $c->stash->{"avatar.$lookup"};

        if($avatar =~ /\@/) {
          $avatar = sprintf '//gravatar.com/avatar/%s?s=40&d=retro', Mojo::Util::md5_sum($avatar);
        }
        else {
          $avatar = sprintf '//graph.facebook.com/%s/picture?height=40&width=40', $avatar;
        }

        $_->{avatar} = $avatar for @{ $cache->{messages} };
        $cb->();
      }
    );
  }

  push @{ $cache->{messages} }, $message;
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

=head2 redirect_last $login

Redirect to the last visited channel for $login. Falls back to settings.

=cut

sub redirect_last {
  my ($self,$login)=@_;
  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->zrevrange("user:$login:conversations", 0, 1, $delay->begin);
    },
    sub {
      my($delay, $names) = @_;

      if($names and $names->[0]) {
        if(my($server, $target) = id_as $names->[0]) {
          return $self->redirect_to('view', server => $server, target => $target);
        }
      }

      $self->redirect_to('settings');
    }
  );
}

=head1 METHODS

=head2 register

Will register the L</HELPERS> above.

=cut

sub register {
  my ($self, $app) = @_;

  $app->helper(format_conversation => \&format_conversation);
  $app->helper(logf                => \&Convos::Core::Util::logf);
  $app->helper(format_time => sub { shift; format_time(@_); });
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
