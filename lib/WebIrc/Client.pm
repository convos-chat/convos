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

  if($self->param('host') and $self->param('channels'), and $self->param('nick')) {
    $self->core->add_connection($self->session('uid'),{
      nick     => $self->param('nick'),
      host     => $self->param('host'),
      user     => $self->session('login'),
      channels => $self->param('channels'),
      }),$self->parallol(sub {
        my $cid=shift;
        $self->redirect_to('view',
          server => $self->param('server'),
          target => $self->param('target'),
        );
    });
  }
  else {
    $self->stash('messsage' => 'Please fill in all the fields to continue');
  }
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self = shift;
  my $redis = $self->app->redis;
  my $connections = {};
  my $msg_name = $self->stash('target') || $self->stash('server');
  my $target = $self->stash('target') || '';

  $self->render_later;
  $self->stash(connections => $connections);
  $self->stash(chat_title => $msg_name);
  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
  $self->stash(messages => []);

  # TODO: Should probably be "user:x:connections" instead of connections?
  $redis->smembers(connections => sub {
    my($redis, $connection_ids) = @_;

    # need to redirect to setup if no servers has been configured
    if(@$connection_ids == 0) {
      return $self->redirect_to('setup');
    }

    for my $id (@$connection_ids) {
      my($server, $msg_id);
      $self->redis_then(
        sub { return mget => map { "connection:$id:$_" } qw/ host user nick / },
        sub {
          my($info) = @_;
          $server = $info->[0];
          $msg_id = $connection_ids->[0] if $server eq $self->stash('server');
          $connections->{$server}{id} = shift @$connection_ids;
          $connections->{$server}{user} = $info->[1];
          $connections->{$server}{nick} = $info->[2];
          $connections->{$server}{active} = $info->[0] eq $msg_name ? 1 : 0;
          return smembers => "connection:$id:channels";
        },
        sub {
          my($channels) = @_;
          $connections->{$server}{targets} = [
            map {
              +{
                name => $_,
                active => $target eq $_ ? 1 : 0,
              };
            } @$channels
          ];
          return lrange => "connection:$msg_id:msg:$msg_name", -50, -1 if $msg_id;
          $self->render;
          return;
        },
        sub {
          my($messages) = @_;
          if(@$messages) {
            $self->stash(messages => [
              map {
                my($timestamp, $sender, $message) = split /\0/, $_, 3;
                +{ timestamp => $timestamp, sender => $sender, message => $message };
              } @$messages
            ]);
          }
          $self->render unless @$connection_ids;
        },
      );
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

  # try to avoid inactivity timeout
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

  $self->on(finish => sub {
    $log->debug("Client finished");
  });

  $self->on(message => sub {
    $log->debug("[ws] < $_[1]");
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
      $self->send($JSON->encode({ error => "Cannot send PRIVMSG without target" }));
      return;
    }

    $log->debug("[pubsub] < $irc_message");
    $redis->publish('connection:1:to_server', $irc_message);
  });

  $redis->subscribe('connection:1:from_server', sub {
    my ($redis,$res)=@_;
    for my $message (@$res) {
      $log->debug("[pubsub] > $message");
      $self->send($message) if $message =~ /^\{/; # only pass on json - skip internal redis messages
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
