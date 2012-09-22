package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use List::MoreUtils qw/ zip /;
use WebIrc::Core::Util qw/ unpack_irc /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $JSON = Mojo::JSON->new;

=head1 METHODS

=head2 view

Used to render the main IRC client view.

=cut

sub view {
    my $self = shift;
    my $uid = $self->session('uid');
    my @keys = qw/ channels nick host /;
    my($connections, $active, $cid, $cname);

    $self->render_later;
    Mojo::IOLoop->delay(
      sub {
        $self->redis->smembers("user:$uid:connections", $_[0]->begin);
      },
      sub {
        $connections = $_[1] || [];
        $self->redis->execute(
          (map { [ hmget => "connection:$_" => @keys ] } @$connections),
          $_[0]->begin,
        );
      },
      sub {
        my($delay, @info) = @_;

        for my $info (@info) {
          $info = { zip @keys, @$info };
          $info->{channels} = [ split /,/, $info->{channels} ];
          $info->{id} = shift @$connections;
        }

        @info = sort { $a->{host} cmp $b->{host} } @info;
        $self->stash(connections => \@info);

        for(@info) {
          $cname ||= $_->{channels}[0];
          $cid = $_->{id};
          $cname and last;
        }

        $active ||= $cname || $cid;
        $self->stash(connection_id => $cid);
        $self->stash(conversation_name => $cname);
        $self->redis->lrange("connection:$cid:$cname:msg", -50, -1, $delay->begin);
      },
      sub {
        my($delay, $conversation) = @_;

        $_ = unpack_irc $_ for @$conversation;

        $self->stash(conversation => $conversation);
        $self->stash(active => $active);
        $self->render;
      }
    );
}

=head2 socket

TODO

=cut

sub socket {
  my $self = shift;
  my $uid = $self->session('uid');
  my %allowed;

  # try to avoid inactivity timeout
  Mojo::IOLoop->stream($self->tx->connection)->timeout(0);

  $self->on(finish => sub {
    $self->logf(debug => "Client finished");
  });

  $self->on(message => sub {
    $self->logf(debug => '[ws] < %s', $_[1]);
    my ($self,$message) = @_;
    $message;
    my $data = $JSON->decode($message) || {};
    my $cid = $data->{cid}; # TODO: report invalid message?
    if(!$cid) {
      $self->logf(debug => "Invalid message:\n".$message. "\nerr:".$JSON->error);
      return;
    }
    
    if($allowed{$cid}) {
      $self->_handle_socket_data($cid => $data);
    }
    else {
      $self->redis->sismember("user:$uid:connections", $cid, sub {
        $self->logf(debug => 'Allowed to listen to %s? %s', $cid, $_[1] ? 'Yes' : 'No');
        $_[1] or return $self->finish; # TODO: Report 401 to user?
        $allowed{$cid} = 1;
        $self->_subscribe_to_server_messages($cid);
        $self->_handle_socket_data($cid => $data);
      });
    }
  });
}

sub _handle_socket_data {
  my($self, $cid, $data) = @_;
  my $cmd;

  if($data->{cmd}) {
    if($data->{cmd} =~ s!^/(\w+)\s+(\S*)!!) {
      my($one, $two) = ($1, $2);
      given($one) {
        when('msg') { $data->{cmd} = "PRIVMSG :$two" .$data->{cmd} }
        default { $data->{cmd} = uc $one ." :$two" . $data->{cmd} }
      }
    }
    else {
      $data->{cmd} = sprintf 'PRIVMSG %s :%s', $data->{cname}, $data->{cmd};
    }

    $self->logf(debug => '[connection:%s:to_server] < %s', $cid, $data->{cmd});
    $self->redis->publish("connection:$cid:to_server", $data->{cmd});
  }
}

sub _subscribe_to_server_messages {
  my($self, $cid) = @_;

  $self->redis->subscribe("connection:$cid:from_server", sub {
    my ($redis,$res)=@_;
    for my $message (@$res) {
      #$self->logf(debug => '[connection:%s:from_server] > %s', $cid, $message);
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
