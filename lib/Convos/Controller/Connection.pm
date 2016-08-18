package Convos::Controller::Connection;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';

sub create {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $url  = Mojo::URL->new($json->{url});
  my $name = $json->{name} || $self->_pretty_connection_name($url->host);
  my $connection;

  if (!$name) {
    return $self->render(openapi => E('URL need a valid host.', '/body/url'), status => 400);
  }
  if ($user->get_connection({protocol => $url->scheme, name => $name})) {
    return $self->render(openapi => E('Connection already exists.'), status => 400);
  }

  eval {
    $connection = $user->connection({protocol => $url->scheme, name => $name});
    $connection->url->parse($url);
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

sub rooms {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $connection = $user->get_connection($self->stash('connection_id'));

  unless ($connection) {
    return $self->render(openapi => E('Connection not found.'), status => 404);
  }

  $self->delay(
    sub { $connection->rooms(shift->begin) },
    sub {
      my ($delay, $err, $rooms) = @_;
      $self->render(openapi => {rooms => $rooms});
    },
  );
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $json = $self->req->json;
  my $state = $json->{state} || '';
  my $url = Mojo::URL->new($json->{url} || '');
  my $connection;

  eval {
    $connection = $user->get_connection($self->stash('connection_id'));
    $connection->url->host or die 'Connection not found';
  } or do {
    return $self->render(openapi => E('Connection not found.'), status => 404);
  };

  if ($url->host) {
    $url->scheme($json->{protocol});
    $state = 'reconnect' if $url->to_string ne $connection->url->to_string;
    $connection->url->parse($url);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
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

=head2 rooms

See L<Convos::Manual::API/roomsForConnection>.

=head2 update

See L<Convos::Manual::API/updateConnection>.

=head1 SEE ALSO

L<Convos>.

=cut
