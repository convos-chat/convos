package Convos::Controller::Connection;

=head1 NAME

Convos::Controller::Connection - Convos connection actions

=head1 DESCRIPTION

L<Convos::Controller::Connection> is a L<Mojolicious::Controller> with
user related actions.

=cut

use Mojo::Base 'Mojolicious::Controller';
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

=head1 METHODS

=head2 create

See L<Convos::Manual::API/createConnection>.

=cut

sub create {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $url  = Mojo::URL->new($args->{body}{url});
  my $name = $args->{body}{name} || $self->_pretty_connection_name($url->host);
  my $connection;

  unless ($name) {
    return $self->$cb($self->invalid_request('URL need a valid host.', '/body/url'), 400);
  }

  eval {
    die 'DUP' if $user->connection($url->scheme, $name)->url->host;
    $connection = $user->connection($url->scheme, $name, {});
    $connection->url->parse($url);
  } or do {
    return $self->$cb($self->invalid_request('Connection already exists.', '/'), 400) if $@ =~ /^DUP\s/;
    return $self->$cb($self->invalid_request('Could not find connection class from scheme.', '/body/url'), 400);
  };

  $self->delay(
    sub { $connection->save(shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->$cb($connection->TO_JSON, 200);
    },
  );
}

=head2 list

See L<Convos::Manual::API/listConnections>.

=cut

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @connections;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    push @connections, $connection->TO_JSON;
  }

  $self->$cb({connections => \@connections}, 200);
}

=head2 remove

See L<Convos::Manual::API/removeConnection>.

=cut

sub remove {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);

  $self->delay(
    sub {
      $user->remove_connection($args->{protocol}, $args->{connection_name}, shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->$cb({}, 200);
    },
  );
}

=head2 rooms

See L<Convos::Manual::API/roomsForConnection>.

=cut

sub rooms {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{protocol}, $args->{connection_name});

  unless ($connection->url->host) {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  }

  $self->delay(
    sub { $connection->rooms(shift->begin) },
    sub {
      my ($delay, $err, $rooms) = @_;
      $self->$cb({rooms => [map { $_->TO_JSON } @$rooms]}, 200);
    },
  );
}

=head2 update

See L<Convos::Manual::API/updateConnection>.

=cut

sub update {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $state = $args->{body}{state} || '';
  my $url = Mojo::URL->new($args->{body}{url} || '');
  my $connection;

  eval {
    $connection = $user->connection($args->{protocol}, $args->{connection_name});
    $connection->url->host or die 'Connection not found';
  } or do {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  };

  if ($url->host) {
    $url->scheme($args->{protocol});
    $state = 'reconnect' if $url->to_string ne $connection->url->to_string;
    $connection->url->parse($url);
  }

  $self->delay(
    sub {
      my ($delay) = @_;
      $connection->save($delay->begin);
      $connection->disconnect($delay->begin) if $state eq 'disconnect' or $state eq 'reconnect';
      $connection->state('connecting') if $state eq 'connect';
    },
    sub {
      my ($delay, $err, $disconnected) = @_;
      die $err if $err;
      $connection->state('connecting') if $state eq 'reconnect';
      $self->$cb($connection->TO_JSON, 200);
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

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
