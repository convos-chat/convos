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
    return $self->send({json => $self->invalid_request('Need to log in first.', '/X-Convos-Session')})->finish;
  }

  $self->_subscribe('_send_event');
  $self->on(message => sub { warn "WebSocket data! $_[1]"; });
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
  $self->send({json => {event => $event, data => $data}});
}

sub _subscribe {
  my ($self, $method) = @_;
  my $tid = Mojo::IOLoop->recurring(INACTIVE_TIMEOUT - 5, sub { $self->$method(keep_alive => {}); });
  my @cb;

  Scalar::Util::weaken($self);

  # This feels a bit awkward. I think I have designed the whole emit()
  # system wrong. Where is the best place to hook in to get events?
  # 1. On each connection and every conversation (like I started on here)
  # 2. Hook in on self->backend, and then filter away all the events that
  #    doesn't belong to this user?
  # 3. Something else?
  # Seems like an awful lot to listen to...
  for my $c (@{$self->backend->user->connections}) {
    push @cb, $c, log => $c->on(
      log => sub {
        my ($c, $level, $message) = @_;
        $self->$method(log => {level => $level, message => $message, name => $c->name, protocol => $c->protocol});
      }
    );
  }

  $self->inactivity_timeout(INACTIVE_TIMEOUT);
  $self->on(
    finish => sub {
      Mojo::IOLoop->remove($tid);
      while (@cb) {
        my ($obj, $event, $cb) = splice @cb, 0, 3, ();
        $obj->unsubscribe($event => $cb) if $obj;    # out of scope
      }
    }
  );
}

sub _write_event {
  my ($self, $event, $data) = @_;
  $data = encode_json $data;
  $self->write("event:$event\ndata:$data\n\n");
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
