package Convos::Controller::Events;

=head1 NAME

Convos::Controller::Events - Stream events from Convos::Core to web

=head1 DESCRIPTION

L<Convos::Controller::Stream> is a L<Mojolicious::Controller> which
can stream events from the backend to frontend, and also act on
input from web, if websocket is supported by the browser.

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'encode_json';
use constant DEBUG            => $ENV{CONVOS_DEBUG}            || 0;
use constant INACTIVE_TIMEOUT => $ENV{CONVOS_INACTIVE_TIMEOUT} || 30;

=head1 METHODS

=head2 bi_directional

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as
JSON objects over a WebSocket connection, but also allows instructions from
the client, since WebSockets are bi-directional.

=cut

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

=head2 event_source

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as
JSON objects using L<Mojolicious::Guides::Cookbook/EventSource web service>.

=cut

sub event_source {
  my $self = shift;

  $self->res->headers->content_type('text/event-stream');

  unless ($self->backend->user) {
    return $self->render(text => qq(event:error\ndata:{"message":"Need to log in first."}\n\n), status => 401);
  }

  $self->render_later;
  $self->_write_event(keep_alive => {});
  $self->_subscribe($self->can('_write_event'));
  $self->on(json => sub { warn "TODO: $_[1]"; });
}

sub _send_event {
  my ($self, $event, $data) = @_;
  $data->{type} = $event;
  warn "[Convos::Controller::Events] >>> @{[encode_json $data]}\n" if DEBUG == 2;
  $self->send({json => $data});
}

sub _subscribe {
  my ($self, $method) = @_;
  my $user = $self->backend->user;
  my $tid = Mojo::IOLoop->recurring(INACTIVE_TIMEOUT - 5, sub { $self->$method(keep_alive => {}); });
  my @cb;

  Scalar::Util::weaken($self);
  for my $event ($user->EVENTS) {
    push @cb, $event, $user->on(
      $event => sub {
        my ($user, $target, @data) = @_;
        if ($event eq 'message') {
          $target = shift(@data)->TO_JSON(1);
          $self->$method($event => {object => $target, data => \@data});
        }
        else {
          $self->$method($event => {object => $target, data => \@data});
        }
      }
    );
  }

  $self->inactivity_timeout(INACTIVE_TIMEOUT);
  $self->on(
    finish => sub {
      Mojo::IOLoop->remove($tid);
      while (@cb) {
        my ($event, $cb) = splice @cb, 0, 2, ();
        $user->unsubscribe($event => $cb);
      }
    }
  );
}

sub _write_event {
  my ($self, $event, $data) = @_;
  $data = encode_json $data;
  warn "[Convos::Controller::Events] >>> event:$event\ndata:$data\n" if DEBUG == 2;
  $self->write("event:$event\ndata:$data\n\n");
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
