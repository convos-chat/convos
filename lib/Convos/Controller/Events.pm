package Convos::Controller::Events;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'encode_json';
use Convos::Util 'DEBUG';

use constant INACTIVE_TIMEOUT => $ENV{CONVOS_INACTIVE_TIMEOUT} || 30;

sub bi_directional {
  my $self = shift;

  unless ($self->backend->user) {
    return $self->send({json => $self->invalid_request('Need to log in first.', '/')})->finish;
  }

  $self->_subscribe('_send_event');
  $self->on(
    json => sub {
      my ($c, $data) = @_;
      warn "[Convos::Controller::Events] <<< @{[Mojo::JSON::encode_json($data)]}\n" if DEBUG == 2;
      return if $c->dispatch_to_swagger($data);
    }
  );
}

sub event_source {
  my $self = shift;

  $self->res->headers->content_type('text/event-stream');

  unless ($self->backend->user) {
    return $self->render(
      text   => qq(event:error\ndata:{"message":"Need to log in first."}\n\n),
      status => 401
    );
  }

  $self->render_later;
  $self->_write_event(noop => {});
  $self->_subscribe($self->can('_write_event'));
}

sub send {

  # TODO: This is really not nice, but I can't seem to figure out a better
  # name for "sendEvents" in the API spec.
  return shift->SUPER::send(@_) unless ref $_[2] eq 'CODE';

  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{body}{connection_id});

  unless ($connection) {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  }

  $self->delay(
    sub { $connection->send($args->{body}{dialog_id}, $args->{body}{command}, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      $res->{command} = $args->{body}{command};
      return $self->$cb($res, 200) unless $err;
      return $self->$cb($self->invalid_request($err), 500);
    },
  );
}

sub _send_event {
  my ($self, $event, $data) = @_;
  $data->{event} = $event;
  warn "[Convos::Controller::Events] >>> @{[encode_json $data]}\n" if DEBUG == 2;
  $self->send({json => $data});
}

sub _subscribe {
  my ($self, $method) = @_;
  my $uid     = $self->backend->user->id;
  my $backend = $self->app->core->backend;

  Scalar::Util::weaken($self);
  my $tid = Mojo::IOLoop->recurring(INACTIVE_TIMEOUT - 5, sub { $self->$method(noop => {}); });
  my $cb = $backend->on(
    "user:$uid" => sub {
      my ($backend, $event, $data) = @_;
      my $ts = Mojo::Date->new($data->{ts} || time)->to_datetime;
      $self->$method($event => {%$data, ts => $ts});
    }
  );

  $self->inactivity_timeout(INACTIVE_TIMEOUT);
  $self->on(
    finish => sub {
      Mojo::IOLoop->remove($tid);
      $backend->unsubscribe("user:$uid" => $cb);
    }
  );
}

sub _write_event {
  my ($self, $event, $data) = @_;
  $data = encode_json $data;
  warn "[Convos::Controller::Events] >>> event:$event\ndata:$data\n" if DEBUG == 2;
  $self->write("event:$event\ndata:$data\n\n");
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

=head2 bi_directional

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as
JSON objects over a WebSocket connection, but also allows instructions from
the client, since WebSockets are bi-directional.

=head2 event_source

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as
JSON objects using L<Mojolicious::Guides::Cookbook/EventSource web service>.

=head2 send

See L<Convos::Manual::API/sendEvents>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
