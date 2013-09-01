package WebIrc::Chat;

=head1 NAME

WebIrc::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'j';
use constant PING_INTERVAL => $ENV{WIRC_PING_INTERVAL} || 30;
use WebIrc::Core::Commands;

=head1 METHODS

=head2 socket

Handle conversation exchange over websocket.

=cut

sub socket {
  my $self = shift;
  my $login = $self->session('login');
  my $key = "wirc:user:$login:out";
  my($sub, $tid);

  Mojo::IOLoop->stream($self->tx->connection)->timeout(PING_INTERVAL * 2);

  # send ping frames
  Scalar::Util::weaken($self);
  $tid = Mojo::IOLoop->recurring(PING_INTERVAL, sub {
           $self->send([1, 0, 0, 0, 9, 'pin']);
         });

  # from browser to backend
  $self->on(
    message => sub {
      my ($self, $octets) = @_;
      my $dom = Mojo::DOM->new($octets)->at('div');

      $self->logf(debug => '[ws] < %s', $octets);

      if($dom and $dom->attr('id') and $dom->attr('data-host')) {
        $self->_handle_socket_data($dom);
      }
      else {
        $self->send_partial(
          'event/server_message',
          status => 400,
          host => $dom->{'data-host'} || 'any',
          message => "Invalid message ($octets)",
          timestamp => time,
          uuid => '',
        )->finish;
      }
    }
  );
  $self->on(
    finish => sub {
      my $self = shift;
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

  @$dom{qw/ host target /} = map { delete $dom->{$_} || '' } qw/ data-host data-target /;
  $dom->{timestamp} ||= time;

  if ($cmd =~ s!^/(\w+)\s*(.*)!!) {
    my($action, $arg) = ($1, $2);
    $arg =~ s/\s+$//;
    if (my $code = WebIrc::Core::Commands->can($action)) {
      $cmd = $self->$code($arg, $dom);
    }
    else {
      $self->send_partial('event/server_message', status => 400, message => 'Unknown command. Type /help to see available commands.');
      $cmd = undef;
    }
  }
  elsif($dom->{target}) {
    $cmd = "PRIVMSG $dom->{target} :$cmd";
  }
  else {
    $cmd = undef;
  }

  if(defined $cmd) {
    my $key = "wirc:user:$login:$dom->{host}";
    $cmd = "$dom->{id} $cmd";
    $self->logf(debug => '[%s] < %s', $key, $cmd);
    $self->redis->publish($key => $cmd);
    if($dom->{'data-history'}) {
      $self->redis->rpush("user:$login:cmd_history", $dom->text(0));
      $self->redis->ltrim("user:$login:cmd_history", -30, -1);
    }
  }
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
