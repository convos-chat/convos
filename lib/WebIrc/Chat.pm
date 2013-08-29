package WebIrc::Chat;

=head1 NAME

WebIrc::Chat - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

my $JSON = Mojo::JSON->new;
my %COMMANDS; %COMMANDS = (
  j     => \'join',
  join  => 'JOIN',
  t     => \'topic',
  topic => sub { my $dom = pop; "TOPIC $dom->{target}" . ($dom->{cmd} ? ' :' . $dom->{cmd} : '') },
  w     => \'whois',
  whois => 'WHOIS',
  list  => 'LIST',
  nick  => 'NICK',
  oper => sub { my $dom = pop; "OPER $dom->{cmd}" },
  mode => sub { my $dom = pop; "MODE $dom->{cmd}" },
  names => sub { my $dom = pop; "NAMES " . ($dom->{cmd} || $dom->{target}) },
  me   => sub { my $dom = pop; "PRIVMSG $dom->{target} :\x{1}ACTION $dom->{cmd}\x{1}" },
  msg  => sub { my $dom = pop; $dom->{cmd} =~ s!^(\w+)\s*!!; "PRIVMSG $1 :$dom->{cmd}" },
  part => sub { my $dom = pop; "PART " . ($dom->{cmd} || $dom->{target}) },
  query=> sub {
    my ($self, $dom) = @_;
    my $login = $self->session('login');
    my $target = $dom->{cmd} || $dom->{target};
    my $id = $self->as_id($dom->{host}, $target);

    $self->redis->zrem("user:$login:conversations", $id, sub {
      $self->send_partial('event/add_conversation', %$dom, target => $target);
    });
    return;
  },
  close => sub {
    my ($self, $dom) = @_;
    my $login = $self->session('login');
    my $target = $dom->{cmd} || $dom->{target};
    my $id = $self->as_id($dom->{host}, $target);

    return "PART $target" if $target =~ /^#/;
    $self->redis->zrem("user:$login:conversations", $id, sub {
      $self->send_partial('event/remove_conversation', %$dom, target => $target);
    });
    return;
  },
  reconnect => sub {
    my ($self, $dom) = @_;
    $self->app->core->control(restart => $dom->{host}, sub {});
    return;
  },
  help => sub {
    my ($self, $dom) = @_;
    $self->send_partial('event/help');
    return;
  }
);

=head1 METHODS

=head2 socket

Handle conversation exchange over websocket.

=cut

sub socket {
  my $self = shift->render_later;
  my $login = $self->session('login');
  my $key = "wirc:user:$login:out";
  my $sub = $self->redis->subscribe($key);

  Scalar::Util::weaken($self);
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

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

  # from backend to browser
  $sub->timeout(0);
  $sub->on(error => sub { $self->logf(warn => 'sub: %s', pop); $self->finish; });
  $sub->on(
    message => sub {
      my $sub = shift;
      my @messages = (shift);

      $self->logf(debug => '[%s] > %s', $key, $messages[0]);
      $self->format_conversation(
        sub { $JSON->decode(shift @messages) },
        sub {
          my($self, $messages) = @_;
          $self->send_partial("event/$messages->[0]{event}", target => '', %{ $messages->[0] });
        },
      );
    }
  );

  $self->stash(sub => $sub);
  $self->on(finish => sub { $self and delete $self->stash->{sub} });
}

sub _handle_socket_data {
  my ($self, $dom) = @_;
  my $cmd = Mojo::Util::html_unescape($dom->text(0));
  my $login = $self->session('login');
  my($host, $target, $uuid) = map { delete $dom->{$_} || '' } qw/ data-host data-target id /;

  @$dom{qw/ host target uuid/} = ($host, $target, $uuid);

  if ($cmd =~ s!^/(\w+)\s*!!) {
    if (my $irc_cmd = $COMMANDS{$1}) {
      $dom->{cmd} = $cmd =~ s/\s+$//r; # / st2 format hack
      $irc_cmd = $COMMANDS{$$irc_cmd} if ref $irc_cmd eq 'SCALAR';
      $cmd = ref $irc_cmd eq 'CODE' ? $self->$irc_cmd($dom) : "$irc_cmd $cmd";
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

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
