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

=head2 connection_add

See L<Convos::Manual::API/connectionAdd>.

=cut

sub connection_add {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $url  = Mojo::URL->new($args->{data}{url});
  my $name = $args->{data}{name} || $self->_pretty_connection_name($url->host);
  my $connection;

  unless ($name) {
    return $self->$cb($self->invalid_request('URL need a valid host.', '/data/url'), 400);
  }

  eval {
    $connection = $user->connection($url->scheme, $name, {});
    $connection->url->parse($url);
  } or do {
    warn $@ if DEBUG;
    return $self->$cb($self->invalid_request('Could not find connection class from scheme.', '/data/url'), 400);
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

=head2 connection_rooms

See L<Convos::Manual::API/connectionRooms>.

=cut

sub connection_rooms {
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

=head2 connections

See L<Convos::Manual::API/connections>.

=cut

sub connections {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @connections;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    push @connections, $connection->TO_JSON;
  }

  $self->$cb({connections => \@connections}, 200);
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
