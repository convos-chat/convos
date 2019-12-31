package Convos::Controller::Events;
use Mojo::Base 'Mojolicious::Controller', -async;

use Convos::Util qw(DEBUG E);
use Mojo::JSON 'encode_json';
use Mojo::Util;
use Time::HiRes 'time';

use constant INACTIVE_TIMEOUT => $ENV{CONVOS_INACTIVE_TIMEOUT} || 60;

sub start {
  my $self = shift->inactivity_timeout(INACTIVE_TIMEOUT);

  return $self->_err('Need to log in first.', {})->finish unless my $user = $self->backend->user;

  Scalar::Util::weaken($self);

  my $uid     = $user->id;
  my $backend = $self->app->core->backend;
  my $cb      = $backend->on(
    "user:$uid" => sub {
      my ($backend, $event, $data) = @_;
      my $ts = Mojo::Date->new($data->{ts} || time)->to_datetime;
      warn "[Convos::Controller::Events] >>> @{[encode_json $data]}\n" if DEBUG == 2;
      $self->send({json => {%$data, ts => $ts, event => $event}});
    }
  );

  $self->on(
    finish => sub {
      warn "[Convos::Controller::Events] !!! Finish\n" if DEBUG == 2;
      $backend->unsubscribe("user:$uid" => $cb);
    }
  );

  $self->on(
    json => sub {
      my ($self, $data) = @_;
      my $method = sprintf '_event_%s', $data->{method} || 'ping';
      $data->{id} //= Mojo::Util::steady_time();
      warn "[Convos::Controller::Events] <<< @{[Mojo::JSON::encode_json($data)]}\n" if DEBUG == 2;
      $self->can($method) ? $self->$method($data) : $self->_err('Invalid method.', $data);
    }
  );
}

sub _err {
  my ($self, $err, $data) = @_;
  my $res = E $err;
  $res->{$_} = $data->{$_} for grep { $data->{$_} } qw(connection_id message id);
  $res->{event} = 'sent';
  $self->send({json => $res});
}

sub _event_debug {
  my ($self, $data) = @_;
  $self->log->debug('[ws] <<< ' . encode_json $data) if DEBUG;
  $self->send({json => {event => 'debug'}});
}

async sub _event_send {
  my ($self, $data) = @_;

  return $self->_err('Invalid input.', $data)
    unless $data->{connection_id} and length $data->{message};

  return $self->_err('Connection not found.', $data)
    unless my $connection = $self->backend->user->get_connection($data->{connection_id});

  eval {
    my $res = await $connection->send_p($data->{dialog_id} // '', $data->{message});
    $res = $res->TO_JSON if UNIVERSAL::can($res, 'TO_JSON');
    $res ||= {};
    $res->{event} = 'sent';
    $res->{$_} ||= $data->{$_} for keys %$data;
    $self->send({json => $res});
  };
  if ($@) {
    $self->_err($@, $data);
  }
}

sub _event_ping {
  $_[0]->send({json => {event => 'pong', ts => time}});
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Events - Stream events from Convos::Core to web

=head1 DESCRIPTION

L<Convos::Controller::Stream> is a L<Mojolicious::Controller> which
can stream events from the backend to frontend, and also act on
input from web, if websocket is supported by the browser.

=head1 METHODS

=head2 start

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as JSON
objects over a WebSocket connection and receive messages from the frontend.

=head1 SEE ALSO

L<Convos>:

=cut
