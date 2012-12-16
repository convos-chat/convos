package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use Unicode::UTF8;
no warnings "utf8";
use Mojo::Util 'html_escape';
use List::MoreUtils qw/ zip /;
use WebIrc::Core::Util qw/ unpack_irc /;
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $N_MESSAGES = 50;
my $JSON = Mojo::JSON->new;

=head1 METHODS

=head2 view

Used to render the main IRC client view.

=cut

sub route {
  my $self=shift;
  my $uid = $self->session('uid');
  return $self->render(template => 'index') unless $uid;
  return $self->redirect_to( $self->session('current_active')) if $self->session('current_active');
  $self->render_later;
  my ($connections,$channels);
  Mojo::IOLoop->delay( sub {
    $self->redis->smembers("user:$uid:connections",shift->begin);
  }, sub {
    $connections=pop;
    $self->redirect_to($self->url_for('settings')) unless @$connections;
    $self->redis->smembers('connection:'.$connections->[0].':channels',shift->begin);
  }, sub {
    $channels=pop;
    return $self->redirect_to($self->url_for('channel.view',cid => $connections->[0],target=>$channels->[0])) if @$channels;
    $self->redirect_to($self->url_for('settings'));
  });
}

sub view {
  my $self = shift->render_later;
  $self->session('current_active' => $self->url_for);
  my $uid = $self->session('uid');
  my @keys = qw/ nick host /;
  my($connections);
  my $target=$self->param('target');
  my $cid=$self->param('cid');


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

      my $cb=$delay->begin;
      for my $info (@info) {
        $info = { zip @keys, @$info };
        $info->{id} = shift @$connections;
        $self->redis->execute(
          ['smembers', "connection:".$info->{id}.':channels'],
          ['smembers', "connection:".$info->{id}.':conversations'], sub {
          my ($redis,$channels,$conversations) = @_;
          $info->{channels}=$channels;
          $info->{conversations}=$conversations;
        });
        
      }

      @info = sort { $a->{host} cmp $b->{host} } @info;
      $cid //= $info[0]{id};
      $target //= $info[0]{channels}[0];

      $self->stash(
        connections => \@info,
        nick => $info[0]{nick},
        connection_id => $cid,
        target => $target,
      );
      $self->session(
        nick => $info[0]{nick},
        target => $target,
        connection_id => $cid,
      );

      # FIXME: Should be using last seen tz and default to -inf
      my $redis_key = $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";
      $self->redis->zrevrangebyscore(
        $redis_key,
        "+inf" => "-inf",
        "withscores",
        "limit" => 0, $N_MESSAGES,
        $cb,
      );
    },
    sub {
      $self->stash(conversation => $self->_format_conversation($_[1]));
      return $self->render(nicks => []) if(!$target);
      $self->redis->smembers("connection:$cid:$target:nicks", $_[0]->begin);
    },
    sub {
      $self->render(nicks => $_[1]);
    }
  );
}

=head2 history

=cut

sub history {
  my $self = shift->render_later;
  my $page = $self->param('page');
  my $cid = $self->session('connection_id');
  my $target = $self->session('target') // '';

  unless($page and $cid) {
    return $self->render_exception('Missing parameters'); # TODO: Need to have a better error message?
  }

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      my $offset = ($page - 1) * $N_MESSAGES;
      
      my $redis_key= $target ? "connection:$cid:$target:msg" : "connection:$cid:msg";

      $self->redis->zrevrangebyscore(
        $redis_key,
        "+inf" => "-inf",
        "withscores",
        "limit" => $offset, $offset + $N_MESSAGES,
        $delay->begin,
      );
    },
    sub {
      $self->render(
        connection_id => $cid,
        connections => [],
        nicks => [],
        conversation => $self->_format_conversation($_[1]),
        nick => $self->session('nick'),
        target => $target,
        template => 'client/view',
      );
    }
  );
}

sub _format_conversation {
  my($self, $conversation) = @_;
  my $nick = $self->session('nick');
  my $messages = [];

  for(my $i = 0; $i < @$conversation; $i = $i + 2) {
    my $message = unpack_irc $conversation->[$i], $conversation->[$i + 1];
    $message->{message} = html_escape $message->{params}[1];
    $message->{message} =~ s!\b(\w{2,5}://\S+)!<a href="$1" target="_blank">$1</a>!gi;
    $message->{nick} = $message->{prefix} =~ /^(.*?)!/ ? $1 : '';
    $message->{class_name} = $message->{message} =~ /\b$nick\b/ ? 'focus'
                           : $message->{special} eq 'me'     ? 'action'
                           : $message->{nick} eq $nick       ? 'me'
                           :                                   '';

    unshift @$messages, $message;
  }

  return $messages;
}

=head2 socket

TODO

=cut

sub socket {
  my $self = shift;
  my $uid = $self->session('uid');

  # try to avoid inactivity timeout
  Mojo::IOLoop->stream($self->tx->connection)->timeout(0);

  $self->on(finish => sub {
    $self->logf(debug => "Client finished");
  });
  $self->redis->smembers("user:$uid:connections", sub {
    my ($reds,$cids)=@_;
    $self->_subscribe_to_server_messages($_) for @$cids;
    my %allowed=map { $_ => 1 } @$cids;

    $self->on(message => sub {
      $self->logf(debug => '[ws] < %s', $_[1]);
      my ($self,$octets) = @_;
      my $message= Unicode::UTF8::encode_utf8($octets, sub { $_[0] });;
      my $data = $JSON->decode($message) || {};
      my $cid = $data->{cid};
      if(!$cid) {
        $self->logf(debug => "Invalid message:\n".$message. "\nerr:".$JSON->error);
        return;
      }
      return $self->_handle_socket_data($cid => $data) if($allowed{$cid});

      $self->send({ text => $JSON->encode({ cid => $cid, status => 403 }) });
      return $self->finish;
    });
  });
}

sub _handle_socket_data {
  my($self, $cid, $data) = @_;
  my $cmd;

  if($data->{cmd}) {
    if($data->{cmd} =~ s!^/(\w+)\s+(\S*)!!) {
      my($one, $two) = ($1, $2);
      given($one) {
        when('j') { 
          $data->{cmd} = "JOIN $two";
        }
        when('me') { $data->{cmd} = "PRIVMSG $data->{target} :\x{1}ACTION $two$data->{cmd}\x{1}" }
        when('msg') { $data->{cmd} = "PRIVMSG $two :$data->{cmd}" }
        default { $data->{cmd} = join ' ', uc($one), $two }
      }
    }
    elsif($data->{cmd} =~ m!/part\s*!i) {
      $data->{cmd} = "PART $data->{target}";
    }
    else {
      $data->{cmd} = "PRIVMSG $data->{target} :$data->{cmd}";
    }

    $self->logf(debug => '[connection:%s:to_server] < %s', $cid, $data->{cmd});
    $self->redis->publish("connection:$cid:to_server", $data->{cmd});
  }
}

sub _subscribe_to_server_messages {
  my($self, $cid) = @_;
  my $sub = $self->redis->subscribe("connection:$cid:from_server");

  $sub->on(message => sub {
    my ($redis, $octets)=@_;
    my $message=Unicode::UTF8::decode_utf8($octets, sub { $_[0] });
    $self->logf(debug => '[connection:%s:from_server] > %s', $cid, $message);
    $self->send({ text => $message });
  });

  $self->stash("sub_$cid" => $sub);
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
