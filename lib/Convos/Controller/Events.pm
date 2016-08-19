package Convos::Controller::Events;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util qw(DEBUG E);
use Mojo::JSON 'encode_json';
use Mojo::Util;

use constant INACTIVE_TIMEOUT => $ENV{CONVOS_INACTIVE_TIMEOUT} || 30;

sub start {
  my $self = shift;
  my $user = $self->backend->user or return $self->_err('Need to log in first.', {})->finish;

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

  $self->inactivity_timeout(INACTIVE_TIMEOUT);
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
  my ($self, $msg, $data) = @_;
  my $res = E $msg;
  $res->{id} = $data->{id} if $data->{id};
  $self->send({json => $res});
}

sub _event_send {
  my ($self, $data) = @_;
  my $connection = $self->backend->user->get_connection($data->{connection_id})
    or return $self->_err('Connection not found.', $data);

  $self->delay(
    sub { $connection->send($data->{dialog_id}, $data->{message}, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      return $self->_err($err, $data) if $err;
      $res = $res->TO_JSON if UNIVERSAL::can($res, 'TO_JSON');
      @$res{qw(connection_id event id message)} = ($connection->id, 'sent', @$data{qw(id message)});
      $self->send({json => $res});
    },
  );
}

sub _event_ping { $_[0]->send({json => {ts => Mojo::Util::steady_time()}}) }

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
