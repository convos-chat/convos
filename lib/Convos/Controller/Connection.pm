package Convos::Controller::Connection;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::Util 'trim';

sub create {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $url  = $self->_validate_url($json->{url})
    or return $self->render(openapi => E('Missing "host" in URL'), status => 400);
  my $name = $json->{name} || $self->_pretty_connection_name($url->host);
  my $connection;

  if (!$name) {
    return $self->render(openapi => E('URL need a valid host.', '/body/url'), status => 400);
  }
  if ($user->get_connection({protocol => $url->scheme, name => $name})) {
    return $self->render(openapi => E('Connection already exists.'), status => 400);
  }

  eval {
    $connection = $user->connection(
      {
        name                => $name,
        on_connect_commands => $json->{on_connect_commands} || [],
        protocol            => $url->scheme,
      }
    );
    $connection->url($url);
    $self->delay(
      sub { $connection->save(shift->begin) },
      sub {
        my ($delay, $err) = @_;
        die $err if $err;
        $self->app->core->connect($connection);
        $self->render(openapi => $connection);
      },
    );
    1;
  } or do {
    $self->render(openapi => E($@ || 'Unknown error'), status => 400);
  };
}

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my @connections;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    push @connections, $connection;
  }

  $self->render(openapi => {connections => \@connections});
}

sub remove {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  $self->delay(
    sub {
      $user->remove_connection($self->stash('connection_id'), shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(openapi => {});
    },
  );
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $state = $json->{state} || '';
  my $connection;

  eval {
    $connection = $user->get_connection($self->stash('connection_id'));
    $connection->url->host or die 'Connection not found';
  } or do {
    return $self->render(openapi => E('Connection not found.'), status => 404);
  };

  if (my $cmds = $json->{on_connect_commands}) {
    $cmds = [map { trim $_} @$cmds];
    $connection->on_connect_commands($cmds);
  }
  if (my $url = $self->_validate_url($json->{url})) {
    $url->scheme($json->{protocol} || $connection->url->scheme || '');
    $state = 'reconnect' if not _same_url($url, $connection->url) and $state ne 'disconnect';
    $connection->url($url);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $state = '' if $connection->state eq 'connected' and $state eq 'connect';
      $connection->save($delay->begin);
      $connection->disconnect($delay->begin) if $state eq 'disconnect' or $state eq 'reconnect';
    },
    sub {
      my ($delay, $err, $disconnected) = @_;
      die $err if $err;
      $self->app->core->connect($connection) if $state eq 'connect' or $state eq 'reconnect';
      $self->render(openapi => $connection);
    },
  );
}

sub _pretty_connection_name {
  my ($self, $name) = @_;

  return '' unless defined $name;
  return 'magnet' if $name =~ /\birc\.perl\.org\b/i;    # also match ssl.irc.perl.org
  return 'efnet'  if $name =~ /\befnet\b/i;

  $name =~ s!^(irc|chat)\.!!;                           # remove common prefixes from server name
  $name =~ s!:\d+$!!;                                   # remove port
  $name =~ s!\.\w{2,3}$!!;                              # remove .com, .no, ...
  $name =~ s![\W_]+!-!g;                                # make pretty url
  $name;
}

sub _same_url {
  my ($u1, $u2) = @_;
  my $userinfo = $u1->password ? $u1->userinfo : $u1->username ? join ':', $u1->username,
    $u2->password // '' : '';

  $u1->userinfo($userinfo);

  return 0 unless $u1->host_port eq $u2->host_port;
  return 0 unless +($u1->query->param('tls') || '0') eq +($u2->query->param('tls') || '0');
  return 0 unless $userinfo eq +($u2->userinfo // '');
  return 1;
}

sub _validate_url {
  my ($self, $url) = @_;
  my $forced_irc_server = $self->app->config('forced_irc_server');
  $url = Mojo::URL->new($url || '');
  $url->host_port($forced_irc_server) if $forced_irc_server;
  return $url->host ? $url : undef;
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Connection - Convos connection actions

=head1 DESCRIPTION

L<Convos::Controller::Connection> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 create

See L<Convos::Manual::API/createConnection>.

=head2 list

See L<Convos::Manual::API/listConnections>.

=head2 remove

See L<Convos::Manual::API/removeConnection>.

=head2 update

See L<Convos::Manual::API/updateConnection>.

=head1 SEE ALSO

L<Convos>.

=cut
