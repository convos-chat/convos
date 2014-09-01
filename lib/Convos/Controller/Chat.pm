package Convos::Controller::Chat;

=head1 NAME

Convos::Controller::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'j';
use Mojo::Util qw( html_unescape xml_escape );
use Convos::Core::Commands;
use Time::HiRes 'time';
use constant DEFAULT_RESPONSE => "Hey, I don't know how to respond to that. Try /help to see what I can so far.";

=head1 METHODS

=head2 socket

Handle conversation exchange over websocket.

=cut

sub socket {
  my $self  = shift;
  my $login = $self->session('login');
  my $key   = "convos:user:$login:out";

  $self->_schedule_day_changed_event;
  $self->inactivity_timeout(60);
  Scalar::Util::weaken($self);

  # from browser to backend
  $self->on(
    message => sub {
      my ($self, $octets) = @_;
      my $dom;

      $self->logf(debug => '[ws] < %s', $octets);

      if ($octets eq 'PING') {
        return $self->redis->execute(
          PING => sub {
            $_[1] ? $self->send('PONG') : $self->finish;
          }
        );
      }

      $dom = Mojo::DOM->new($octets)->at('div');

      if ($dom and $dom->{'id'} and $dom->{'data-network'}) {
        @$dom{qw( network state target uuid )}
          = map { delete $dom->{$_} // '' } qw( data-network data-state data-target id );
        $self->_handle_socket_data($dom);
      }
      else {
        $octets = xml_escape $octets;
        $self->_send_400($dom, "Invalid message ($octets)")->finish;
      }
    }
  );

  $self->on(
    finish => sub {
      my $tid;
      $self or return;
      delete $self->stash->{redis};
      Mojo::IOLoop->remove($tid) if $tid = $self->stash('day_changed_event_tid');
    }
  );

  # from backend to browser
  $self->redis->on(
    message => $key => sub {
      my ($sub, $err, @messages) = @_;

      return unless $self;
      return $self->finish->logf(warn => '[REDIS] %s', $err) if $err;
      pop @messages;    # remove channel name from messages

      $self->logf(debug => '[%s] > %s', $key, $messages[0]);
      $self->format_conversation(
        sub { j(shift @messages) },
        sub {
          my ($self, $messages) = @_;
          $self->send_partial("event/$messages->[0]{event}", target => '', %{$messages->[0]});
        },
      );
    }
  );
}

sub _convos_message {
  my ($self, $args, $input, $response) = @_;
  my $login = $self->session('login');

  $self->send_partial(
    'event/message',
    highlight => 0,
    message   => $input,
    nick      => $login,
    network   => $args->{network},
    status    => 200,
    target    => '',
    timestamp => time,
    uuid      => $args->{uuid} . '_',
  );
  $self->send_partial(
    'event/message',
    highlight => 0,
    message   => $response,
    nick      => $args->{network},
    network   => $args->{network},
    status    => 200,
    target    => '',
    timestamp => time,
    uuid      => $args->{uuid},
  );
}

sub _handle_socket_data {
  my ($self, $dom) = @_;
  my $cmd   = html_unescape $dom->text(0);
  my $login = $self->session('login');

  if ($cmd =~ s!^/(\w+)\s*(.*)!!) {
    my ($action, $arg) = ($1, $2);
    $arg =~ s/\s+$//;
    if (my $code = Convos::Core::Commands->can(lc($action))) {
      $cmd = $self->$code($arg, $dom);
    }
    else {
      return $self->_send_400($dom, 'Unknown command. Type /help to see available commands.');
    }
  }
  elsif ($dom->{network} eq 'convos') {
    return $self->_convos_message($dom, $cmd, DEFAULT_RESPONSE);
  }
  elsif ($dom->{target}) {
    $cmd = "PRIVMSG $dom->{target} :$cmd";
  }
  else {
    return;
  }

  if (defined $cmd) {
    my $key = "convos:user:$login:$dom->{network}";
    $cmd = "$dom->{uuid} $cmd";
    $self->logf(debug => '[%s] < %s', $key, $cmd);
    $self->redis->publish($key => $cmd);
    if ($dom->{'data-history'}) {
      $self->redis->rpush("user:$login:cmd_history", $dom->text(0));
      $self->redis->ltrim("user:$login:cmd_history", -30, -1);
    }
  }
}

sub _schedule_day_changed_event {
  my $self = shift;
  my $t    = 86400 - time % 86400;

  Scalar::Util::weaken($self);
  $self->stash(
    day_changed_event_tid => Mojo::IOLoop->timer(
      $t => sub {
        $self or return;
        $self->send_partial('event/day_changed', timestamp => time + 1,);
        $self->_schedule_day_changed_event;
      }
    )
  );
}

sub _send_400 {
  my ($self, $args, $message) = @_;

  $self->send_partial(
    message   => $message,
    network   => $args->{'data-network'} || '',
    status    => 400,
    template  => 'event/server_message',
    timestamp => time,
    uuid      => '',
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
