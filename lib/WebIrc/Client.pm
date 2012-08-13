package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use Parse::IRC;

my $JSON = Mojo::JSON->new;

=head1 METHODS

=head2 setup

=cut

sub setup {
  my $self = shift;

  if($self->param('server') and $self->param('target')) {
    $self->redirect_to('view',
      server => $self->param('server'),
      target => $self->param('target'),
    );
  }
}

=head2 view

Used to render the main IRC client view.
Can serve both HTML and JSON.

=cut

sub view {
  my $self = shift;
  my $redis = $self->app->redis;
  my $connections = {};
  my $chat_title = $self->stash('target') || $self->stash('server');

  $self->render_later;
  $self->stash(connections => $connections);
  $self->stash(chat_title => $chat_title);
  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
  $self->stash(messages => [{
    sender => $chat_title,
    message => 'Connecting...',
  }]);

  # TODO: Should probably be "user:x:connections" instead of connections?
  $redis->smembers(connections => sub {
    my($redis, $connection_ids) = @_;

    if(@$connection_ids == 0) {
      return $self->redirect_to('setup');
    }

    for my $id (@$connection_ids) {
      my @info = map { "connection:$id:$_" } qw/ host user nick /;

      $redis->mget(@info, sub {
        my($redis, $info) = @_;

        $connections->{$info->[0]}{id} = shift @$connection_ids;
        $connections->{$info->[0]}{user} = $info->[1];
        $connections->{$info->[0]}{nick} = $info->[2];
        $connections->{$info->[0]}{active} = $info->[0] eq $chat_title ? 1 : 0;
        @$connection_ids and return;
        $redis->lrange("connection:$id:msg:server", -50, -1, sub {
          $self->stash(messages => [
            map {
              my($time, $message) = split /:/, $_, 2;
              +{ timestamp => $time, message => $message };
            } @{ $_[1] || [] }
          ]);
          $self->render;
        });
      });
    }
  });
}

=head2 socket

TODO

=cut

sub socket {
  my $self = shift;
  my $log = $self->app->log;
  my $redis = $self->app->redis;
  my $pubsub_key = 'connection:1:from_server'; # TODO: Make dynamic

  # try to avoid inactivity timeout
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

  $self->on(finish => sub {
    $log->debug("Client finished, need to drop some connections..?");
  });
  $self->on(message => sub {
    $log->debug("Got message from client: $_[1]");
    my $self = shift;
    my $data = $JSON->decode(shift) or return;
    my $irc_message;

    if($data->{command} =~ m!^/(\w+)\s+(.*)!) {
      $irc_message = sprintf '%s %s', uc($1), $2;
    }
    elsif($data->{target}) {
      $irc_message = sprintf 'PRIVMSG %s :%s', $data->{target}, $data->{command};
    }
    else {
      $self->send($JSON->encode({
        sender => "ERROR",
        params => ["", "Cannot send PRIVMSG without target"],
      }));
      return;
    }

    $redis->publish($pubsub_key, $irc_message);
  });
  $redis->subscribe($pubsub_key, sub {
    my ($redis,$res)=@_;
    for my $message (@$res) {
      # Getting this:
      # Got message from server: subscribe
      # Is this meant to get through? Not sure if "subscribe" and friends
      # are really useful to the end user of Mojo::Redis:
      # subscribe
      # connection:1:from_server
      # 1
      $log->debug("Got message from server: $message");
      $message = parse_irc($message);
      delete $message->{raw_line} or next;
      $message->{prefix} //= $self->param('server'); # TODO: Is this correct?
      $message->{sender} = ($message->{prefix} =~ /^([^!]+)/)[0] || $message->{prefix};
      $message->{command} = IRC::Utils::numeric_to_name($message->{command}) if $message->{command} =~ /^\d+$/;
      $self->send($JSON->encode($message));
    }
  });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
