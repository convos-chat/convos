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
    my $connections;

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
        my($cid, $cname);

        for my $info (@info) {
          $info = { zip @keys, @$info };
          $info->{channels} = [ split /,/, $info->{channels} ];
          $info->{id} = shift @$connections;
        }

        @info = sort { $a->{host} cmp $b->{host} } @info;
        $cid = $info[0]{id};
        $cname = $info[0]{channels}[0];

        $self->stash(connections => \@info);
        $self->stash(nick => $info[0]{nick});
        $self->stash(active => $cname);
        $self->stash(connection_id => $cid);
        $self->stash(conversation_name => $cname);
        # FIXME: Should be using last seen tz and default to -inf
        $self->redis->zrevrangebyscore("connection:$cid:$cname:msg",,'+inf','-inf','withscores','limit', 0, 50, $delay->begin);
      },
      sub {
        my($delay, $conversation) = @_;
        my $msgs=[];
        for(my $i=0; $i < @$conversation; $i=$i+2) {
          unshift $msgs, unpack_irc($conversation->[$i],$conversation->[$i+1])
        }
        $self->stash(conversation => $msgs);
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
    utf8::encode($message);
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
        when('j') { $data->{cmd} = "JOIN $two" }
        when('me') { $data->{cmd} = "PRIVMSG $data->{cname} :\x{1}ACTION $two$data->{cmd}\x{1}" }
        when('msg') { $data->{cmd} = "PRIVMSG $two :$data->{cmd}" }
        default { $data->{cmd} = join ' ', uc($one), $two }
      }
    }
    elsif($data->{cmd} =~ m!/part\s*!i) {
      $data->{cmd} = "PART $data->{cname}";
    }
    else {
      $data->{cmd} = "PRIVMSG $data->{cname} :$data->{cmd}";
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
      utf8::decode($message);
      $self->send({text=>$message}) if $message =~ /^\{/; # only pass on json - skip internal redis messages
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
