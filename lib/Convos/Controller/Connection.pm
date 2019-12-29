package Convos::Controller::Connection;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::Util 'trim';

sub create {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $url = Mojo::URL->new($json->{url} || '');

  if ($self->settings('forced_connection')) {
    my $default_connection = Mojo::URL->new($self->settings('default_connection'));
    return $self->render(openapi => E('Will only accept forced connection URL.'), status => 400)
      if $url->host_port ne $default_connection->host_port;
  }

  return $self->render(openapi => E('Missing "host" in URL'), status => 400) unless $url->host;

  return $self->backend->connection_create_p($url)->then(
    sub {
      my $connection = shift;
      $connection->on_connect_commands($json->{on_connect_commands} || []);
      $connection->wanted_state($json->{wanted_state}) if $json->{wanted_state};
      $self->app->core->connect($connection);
      $self->render(openapi => $connection);
    },
    sub {
      $self->render(openapi => E(shift || 'Could not create connection.'), status => 400);
    },
  );
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

  return $user->remove_connection_p($self->stash('connection_id'))->then(sub {
    $self->render(openapi => {});
  });
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $wanted_state = $json->{wanted_state} || '';
  my $connection;

  eval {
    $connection = $user->get_connection($self->stash('connection_id'));
    $connection->url->host or die 'Connection not found.';
    $connection->wanted_state($wanted_state) if $wanted_state;
    1;
  } or do {
    return $self->render(openapi => E('Connection not found.'), status => 404);
  };

  if (my $cmds = $json->{on_connect_commands}) {
    $cmds = [map { trim $_} @$cmds];
    $connection->on_connect_commands($cmds);
  }

  my $url = Mojo::URL->new($json->{url} || '');
  $url = $connection->url unless $url->host;

  unless ($self->settings('forced_connection')) {
    $url->scheme($json->{protocol} || $connection->url->scheme || '');
    $wanted_state = 'reconnect'
      if $wanted_state ne 'disconnected' and not _same_url($url, $connection->url);
    $connection->url($url);
  }

  my @p = ($connection->save_p);
  $wanted_state = '' if $connection->state eq 'connected' and $wanted_state eq 'connected';
  if ($wanted_state eq 'disconnected' or $wanted_state eq 'reconnect') {
    push @p, $connection->disconnect_p;
  }
  elsif ($url->query->param('nick')) {
    $connection->send_p('', sprintf '/nick %s', $url->query->param('nick'));
  }

  return Mojo::Promise->all(@p)->then(sub {
    $self->app->core->connect($connection)
      if $wanted_state eq 'connected' or $wanted_state eq 'reconnect';
    $self->render(openapi => $connection);
  });
}

sub _pretty_connection_name {
  my ($self, $url) = @_;

  my $name = $url->host;
  my ($username) = split(':', $url->userinfo || '');

  # Support ZNC style logins
  # <user>@<useragent>/<network>
  if (
    defined($username)
    && ($username
      =~ /^(?<name>[a-z0-9_\+-]+)@(?<useragent>[a-z0-9_\+-]+)\/(?<network>[a-z0-9_\+-]+)/i)
    )
  {
    return $+{network} if ($+{network});
  }

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

  return 0 unless $u1->host_port eq $u2->host_port;
  return 0 unless +($u1->query->param('tls') || '0') eq +($u2->query->param('tls') || '0');
  return 0 unless +($u1->userinfo // '') eq +($u2->userinfo // '');
  return 1;
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
