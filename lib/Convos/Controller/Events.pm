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

  my $uid     = $self->backend->user->id;
  my $backend = $self->app->core->backend;

  Scalar::Util::weaken($self);

  # Make sure the WebSocket does not time out
  my $tid
    = Mojo::IOLoop->recurring(INACTIVE_TIMEOUT - 5, sub { $self and $self->send({json => {}}); });

  my $cb = $backend->on(
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
      Mojo::IOLoop->remove($tid);
      $backend->unsubscribe("user:$uid" => $cb);
    }
  );
  $self->on(
    json => sub {
      my ($c, $data) = @_;
      warn "[Convos::Controller::Events] <<< @{[Mojo::JSON::encode_json($data)]}\n" if DEBUG == 2;
      $c->dispatch_to_swagger($data);
    }
  );
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

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
