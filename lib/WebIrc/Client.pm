package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use Parse::IRC;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $JSON = Mojo::JSON->new;

=head1 METHODS

=head2 view

Used to render the main IRC client view.

=cut

sub view {
    my $self = shift;
    # TODO
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
