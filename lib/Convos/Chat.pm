package Convos::Chat;

=head1 NAME

Convos::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'j';
use Convos::Core::Commands;
use constant PING_INTERVAL => $ENV{CONVOS_PING_INTERVAL} || 30;

=head1 METHODS

=head2 socket

Handle conversation exchange over websocket.

=cut

sub socket {
  my $self = shift;
  my $login = $self->session('login');
  my $key = "convos:user:$login:out";
  my($sub, $tid);

  Mojo::IOLoop->stream($self->tx->connection)->timeout(PING_INTERVAL * 2);

  # send ping frames
  Scalar::Util::weaken($self);
  $tid = Mojo::IOLoop->recurring(PING_INTERVAL, sub {
           $self->send('<div class="ping"/>');
         });

  # from browser to backend
  $self->on(
    message => sub {
      my ($self, $octets) = @_;
      my $dom = Mojo::DOM->new($octets)->at('div');
      return if $dom && $dom->attr('class') eq 'pong';
      $self->logf(debug => '[ws] < %s', $octets);

      if($dom and $dom->{'id'} and $dom->{'data-server'}) {
        @$dom{qw/ server target uuid /} = map { delete $dom->{$_} || '' } qw/ data-server data-target id /;
        $self->_handle_socket_data($dom);
      }
      else{
        $self->send_partial('event/server_message',
          status => 400,
          server => $dom->{'data-server'} || 'any',
          message => "Invalid message ($octets)",
          status => 400,
          timestamp => time,
          uuid => '',
        )->finish;
      }
    }
  );
  $self->on(
    finish => sub {
      my $self = shift or return;
      Mojo::IOLoop->remove($tid);
      delete $self->stash->{$_} for qw/ sub redis /;
    }
  );

  # from backend to browser
  $sub = $self->stash->{sub} = $self->redis->subscribe($key);
  $sub->on(
    error => sub {
      $self->logf(warn => 'sub: %s', pop);
      $self->finish;
    }
  );
  $sub->on(
    message => sub {
      my $sub = shift;
      my @messages = (shift);

      $self->logf(debug => '[%s] > %s', $key, $messages[0]);
      $self->format_conversation(
        sub { j(shift @messages) },
        sub {
          my($self, $messages) = @_;
          $self->send_partial("event/$messages->[0]{event}", target => '', %{ $messages->[0] });
        },
      );
    }
  );
}

sub _handle_socket_data {
  my ($self, $dom) = @_;
  my $cmd = Mojo::Util::html_unescape($dom->text(0));
  my $login = $self->session('login');

  if ($cmd =~ s!^/(\w+)\s*(.*)!!) {
    my($action, $arg) = ($1, $2);
    $arg =~ s/\s+$//;
    if (my $code = Convos::Core::Commands->can($action)) {
      $cmd = $self->$code($arg, $dom);
    }
    else {
      return $self->send_partial('event/server_message',
        server => $dom->{server},
        message => 'Unknown command. Type /help to see available commands.',
        status => 400,
        timestamp => time,
        uuid => '',
      );
    }
  }
  elsif($dom->{target}) {
    $cmd = "PRIVMSG $dom->{target} :$cmd";
  }
  else {
    return;
  }

  if(defined $cmd) {
    my $key = "convos:user:$login:$dom->{server}";
    $cmd = "$dom->{uuid} $cmd";
    $self->logf(debug => '[%s] < %s', $key, $cmd);
    $self->redis->publish($key => $cmd);
    if($dom->{'data-history'}) {
      $self->redis->rpush("user:$login:cmd_history", $dom->text(0));
      $self->redis->ltrim("user:$login:cmd_history", -30, -1);
    }
  }
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
