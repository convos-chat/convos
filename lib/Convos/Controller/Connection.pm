package Convos::Controller::Connection;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util 'trim';

sub create {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);
  my $json = $self->req->json;

  my $url = Mojo::URL->new($json->{url} || '');
  $url->path("/$json->{conversation_id}") if $json->{conversation_id};

  my $settings = $self->app->core->settings;
  if ($settings->forced_connection) {
    return $self->reply->errors('Will only accept forced connection URL.', 400)
      if $url->host_port ne $settings->default_connection->host_port;
  }

  return $self->reply->errors('Missing "host" in URL', 400) unless $url->host;
  return $self->backend->connection_create_p($url)->then(
    sub {
      my $connection = shift;
      $connection->on_connect_commands($json->{on_connect_commands} || []);
      $connection->wanted_state($json->{wanted_state}) if $json->{wanted_state};
      $connection->connect_p->catch(sub { });
      $self->render(openapi => $connection);
    },
    sub {
      $self->reply->errors(shift || 'Could not create connection.', 400);
    },
  );
}

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);
  my @connections;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    push @connections, $connection;
  }

  $self->render(openapi => {connections => \@connections});
}

sub remove {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);

  return $user->remove_connection_p($self->stash('connection_id'))->then(sub {
    $self->render(openapi => {});
  });
}

sub update {
  my $self         = shift->openapi->valid_input or return;
  my $user         = $self->backend->user        or return $self->reply->errors([], 401);
  my $json         = $self->req->json;
  my $wanted_state = $json->{wanted_state} || '';
  my ($connection, $nick);

  eval {
    $connection = $user->get_connection($self->stash('connection_id'));
    $connection->url->host or die 'Connection not found.';
    $connection->wanted_state($wanted_state) if $wanted_state;
    1;
  } or do {
    return $self->reply->errors('Connection not found.', 404);
  };

  if (my $cmds = $json->{on_connect_commands}) {
    $cmds = [map { trim $_} @$cmds];
    $connection->on_connect_commands($cmds);
  }

  my $url = Mojo::URL->new($json->{url} || '');
  $url = $connection->url unless $url->host;

  my $settings = $self->app->core->settings;
  if ($settings->forced_connection) {
    my $default = $settings->default_connection->clone;
    $default->query->param($_ => $url->query->param($_))
      for grep { defined $url->query->param($_) } qw(nick realname sasl tls tls_verify);
    $url = $default;
  }
  elsif ($connection->wanted_state eq 'connected' and _url_has_changed($url, $connection->url)) {
    $wanted_state = 'reconnect';
  }

  if ($wanted_state eq 'connected' and $connection->state eq 'connected') {
    $nick = $url->query->param('nick');
    $nick = '' if $nick && $connection->nick eq $nick;
  }

  return $connection->reconnect_delay(0)->url($url)->save_p->then(sub {
    return
        $wanted_state eq 'connected'    ? $connection->connect_p->catch(\&_err_failed_dependency)
      : $wanted_state eq 'disconnected' ? $connection->disconnect_p->catch(\&_err_failed_dependency)
      : $wanted_state eq 'reconnect'    ? $connection->reconnect_p->catch(\&_err_failed_dependency)
      :                                   undef;
  })->then(sub {
    $connection->send_p('', "/nick $nick")->catch(sub { }) if $nick;
    $self->render(openapi => $connection);
  });
}

sub _err_failed_dependency {
  die {errors => [{message => "$_[0]", path => '/wanted_state'}], status => 424};
}

sub _url_has_changed {
  my ($u1, $u2) = @_;
  my ($q1, $q2) = ($u1->query, $u2->query);
  return 1 if $u1->host_port ne $u2->host_port;
  return 1 if +($u1->username            // '') ne +($u2->username             // '');
  return 1 if +($u1->password            // '') ne +($u2->password             // '');
  return 1 if +($q1->param('realname')   // '') ne +($q2->param('realname')    // '');
  return 1 if +($q1->param('sasl')       // '') ne +($q2->param('sasl')        // '');
  return 1 if +($q1->param('tls')        // '0') ne +($q2->param('tls')        // '0');
  return 1 if +($q1->param('tls_verify') // '0') ne +($q2->param('tls_verify') // '0');
  return 1 if +($u1->userinfo            // '') ne +($u2->userinfo             // '');
  return 0;
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

See L<https://convos.chat/api.html#op-post--connections>

=head2 list

See L<https://convos.chat/api.html#op-get--connections>

=head2 remove

See L<https://convos.chat/api.html#op-delete--connection--connection_id->

=head2 update

See L<https://convos.chat/api.html#op-post--connection--connection_id->

=head1 SEE ALSO

L<Convos>.

=cut
