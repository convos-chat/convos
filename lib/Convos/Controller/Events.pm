package Convos::Controller::Events;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util qw(DEBUG);
use List::Util qw(any);
use Mojo::JSON qw(encode_json false true);
use Mojo::Util qw(network_contains);
use Scalar::Util qw(blessed weaken);
use Time::HiRes qw(time);

use constant INACTIVE_TIMEOUT => $ENV{CONVOS_INACTIVE_TIMEOUT} || 60;

# https://github.blog/changelog/2019-04-09-webhooks-ip-changes/
our @WEBHOOK_NETWORKS = split /\s*,\s*/,
  ($ENV{CONVOS_WEBHOOK_NETWORKS} // '140.82.112.0/20,192.30.252.0/22');

my %RESPONSE_EVENT_NAME = (ping => 'pong', send => 'sent');

sub start {
  my $self = shift->inactivity_timeout(INACTIVE_TIMEOUT);
  return $self->_err('Need to log in first.', {method => 'handshake'})->finish(1008)
    unless my $user = $self->backend->user;

  weaken $self;
  my $uid     = $user->id;
  my $backend = $self->app->core->backend;
  my $cb      = $backend->on(
    "user:$uid" => sub {
      my ($backend, $event, $data) = @_;
      my $ts = Mojo::Date->new($data->{ts} || time)->to_datetime;
      warn "[Convos::Controller::Events] >>> $event @{[encode_json $data]}\n" if DEBUG >= 2;
      $self->send({json => {%$data, ts => $ts, event => $event}});
    }
  );

  $self->on(
    finish => sub {
      warn "[Convos::Controller::Events] !!! Finish\n" if DEBUG >= 2;
      $backend->unsubscribe("user:$uid" => $cb);
    }
  );

  $self->on(
    json => sub {
      my ($self, $data) = @_;
      $data->{method} ||= 'ping';
      my $method = sprintf '_event_%s', $data->{method};
      $data->{id} //= Mojo::Util::steady_time();
      warn "[Convos::Controller::Events] <<< @{[Mojo::JSON::encode_json($data)]}\n" if DEBUG >= 2;
      my $res = $self->can($method) ? $self->$method($data) : $self->_err('Invalid method.', $data);
      $res->catch(sub { $self->_err(shift, $data) }) if blessed $res and $res->can('catch');
    }
  );
}

sub webhook {
  my $self = shift->openapi->valid_input or return;

  return $self->reply->errors('Unable to accept webhook request.', 503)
    unless my $bot = eval { $self->bot };

  my $remote_address = $self->tx->remote_address;
  return $self->reply->errors("Invalid source IP $remote_address.", 403)
    unless any { network_contains $_, $remote_address } @WEBHOOK_NETWORKS;

  my $method = sprintf 'handle_webhook_%s_event', $self->stash('provider_name');
  my @res    = $bot->call_actions($method => $self->req->headers, $self->req->json);
  return $self->render(openapi => $res[0]) if $res[0];
  return $self->reply->errors('Unable to deliver the message.', 200);
}

sub _err {
  my ($self, $err, $data) = @_;
  my $res = {errors => [{message => $err}]};
  $res->{$_} = $data->{$_} for grep { $data->{$_} } qw(connection_id message id);
  $res->{event} = $RESPONSE_EVENT_NAME{$data->{method}} || $data->{method} || 'unknown';
  $self->send({json => $res});
}

sub _event_debug {
  my ($self, $data) = @_;
  my $id = $data->{id} || time;
  $self->log->warn('[ws] <<< ' . encode_json $data) if DEBUG;
  $self->send({json => {event => 'debug', id => $id}});
}

sub _event_load {
  my ($self, $data) = @_;
  my $id = $data->{id} || time;

  $self->backend->user->get_p($data->{params} || {})->then(sub {
    my $user     = shift;
    my $settings = $self->app->core->settings;
    $user->{default_connection} = $settings->default_connection->to_string;
    $user->{forced_connection}  = $settings->forced_connection;
    $user->{video_service}      = $settings->video_service;
    $self->send({json => {event => 'load', id => $id, user => $user}});
  });
}

sub _event_ping {
  my ($self, $data) = @_;
  my $ts = time;
  my $id = $data->{id} || $ts;
  $self->send({json => {event => 'pong', id => $id, ts => $ts}});
}

sub _event_send {
  my ($self, $data) = @_;

  return $self->_err('Invalid input.', $data)
    unless $data->{connection_id} and length $data->{message};

  return $self->_err('Connection not found.', $data)
    unless my $connection = $self->backend->user->get_connection($data->{connection_id});

  return $connection->send_p($data->{conversation_id} // '', $data->{message})->then(sub {
    my $res = shift;
    $res = $res->TO_JSON if UNIVERSAL::can($res, 'TO_JSON');
    $res ||= {};
    $res->{event} = 'sent';
    $res->{$_} ||= $data->{$_} for keys %$data;
    $self->send({json => $res});
  })->catch(sub {
    $self->_err(shift, $data);
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Events - Stream events from Convos::Core to web

=head1 DESCRIPTION

L<Convos::Controller::Stream> is a L<Mojolicious::Controller> which can stream
events from the backend, and also act on instructions.

=head1 API

=head2 Overview

The WebSocket API is accessible from L<https://example.com/events>. The
endpoint requires an active L<session|Convos::Controller::User>, meaning the
WebSocket will be closed after sending back an L<error|/Errors> if an active
session is not present.

Once the WebSocket is opened, it will send and receive JSON encoded messages.
The messages sent to the WebSocket I<should> contain a "method" and an "id"
key.

All the code examples below are written in JavaScript, and might require that
the WebSocket is already successfully set up.

=over 2

=item * "id"

The "id" key will be echoed back in the response, so you can pair the request
with the response on the client side. It is highly suggested to pass in an "id"
since WebSocket responses can easily be out of order. The ID can be simply an
incremtal number, such as 1, 2, 3, ..., meaning it doesn't have to be globally
unique.

Note however that purly server side generated messages will not have an "id"
key.

=item * "method"

The default method is "ping", unless specified, though it is highly recommened
to always include a "method". See L</Methods> for a list of supported methods.

=back

=head2 Methods

=head3 debug

This method is only useful if the C<CONVOS_DEBUG> environment variable is set.
If so, this event will simply log whatever data is passed in. This is useful if
you are trying to debug a client where you do not have access to a developer
console. Example message:

  ws.send(JSON.stringify({method: "debug", whatEver: 42, ts: new Date().toISOString()}));

=head3 ping

The "ping" method is used to keep the WebSocket open. Example:

  ws.onmessage = (e) => {
    // "ts" is a high precision epoch timestamp
    // {event: "pong", ts: 1593647381.72949}
    const data = JSON.parse(e.data);
  };

  ws.send(JSON.stringify({method: "ping"});

=head3 send

The "send" method is used to send messages or instructions to a connection. All
the input keys are echoed back, along with the response. Here are the input
keys you can use:

=over 2

=item * connection_id

Must be present and must be a known "connection_id". Will result in an error if
the "connection_id" is invalid.

=item * conversation_id

This key is optional, but must be present if you want to send a message to
specific channel or private conversation.

=item * message

The actual message or instruction to send. An instruction must start with "/", like
"/part", while everything else will be sent as a regular message. To force sending
a message you can use the instruction "/say". Example:

  {
    method: "send",
    connection_id: "irc-libera",
    conversation_id: "#convos",
    message: "/say /part is a command you can use to leave a conversation"
  }

See the actual L<Convos::Core::Connection> to see which actions are supported
and not.

=back

Here is an example on how to use the "send" method:

  ws.onmessage = (e) => {
    // The response will be dependent on what the action actually does
    // {event: "sent", id: 42, ...}
    const data = JSON.parse(e.data);
  };

  ws.send(JSON.stringify({
    method: "send",
    connection_id: "irc-whatever",
    conversation_id: "#conversation_name",
    id: 42,
    message: "some message"
  });

=head2 Errors

Any invalid input or error while trying to handle the instructions will result
in an error structure like this:

  {
    // Required
    event: "sent", # handshake, sent, ...
    errors: [
      {message: "some error", path: "/"}
    ],

    // If present in input
    connection_id: "irc-whatever",
    id: 42,
    message: "some message",
  }

The "path" inside the error element might point to which part was actually
invalid. Example:

    {message: "Missing connection ID.", path: "/connection_id"}

=head2 Server events

A server generated event for a given user will be be passed over the WebSocket.

=head3 Messages

A message sent in a channel, private conversation or generated by the server
will result in a "messsage" event. Example:

  {
    connection_id: "irc-whatever",
    conversation_id: "superwoman",
    from: "Superwoman",
    highlight: false,
    messsage: "Some message",
    ts: 1593647381.72949,
    type: "private",
  }

Details:

=over 2

=item * connection_id

Identities from which connection the message originates from.

=item * conversation_id

An unique ID that identifies the conversation on a given connection.

=item * from

A human readable version of who sent the message.

=item * highlight

True if this message should be highlighted in the user interface. This is true
if your nick is mentioned or if the message matches any
L<Convos::Core::User/highlight_keywords>.

=item * message

The actual message that was sent.

=item * ts

A high precision epoch timestamp.

=item * type

Can be either "private", which is just a normal message, "notice" which is not
a very important message, "action" if the message should be prefixed with the
nickname and "error" if this is an error message.

The value of "type" might change in the future. Suggested values:

  Old     | New
  --------|--------
  private | normal
  notice  | notice
  action  | ?
  error   | error

=back

=head3 State changes

A state change is triggered when the connection, the user or another
participant changes state. It can be everything from when disconnected, nick
changes or join events. Example structure:

  {
    connection_id: "irc-whatever",
    conversation_id: "#conversation_name"
    nick: "Superwoman",
    type: "join",
  }

Details:

=over 2

=item * connection_id

Identities from which connection the message originates from.

=item * conversation_id

An unique ID that identifies the conversation on a given connection.

This key is only present in certain cases. See L</type> below.

=item * from, mode

"from" contains the nick that made the mode change, and "mode" contains the new
"mode".

This key is only present in certain cases. See L</type> below.

=item * frozen

Will contain a reason for why you are not enable to join/talk in a given
conversation. Empty string if everything is ok.

This key is only present in certain cases. See L</type> below.

=item * kicker

The nick of whom kicking "nick".

This key is only present in certain cases. See L</type> below.

=item * name

See L<Convos::Core::Conversation/name>.

This key is only present in certain cases. See L</type> below.

=item * nick

The target nick for this event.

This key is only present in certain cases. See L</type> below.

=item * new_nick, old_nick

Used to identify from what nick and to what nick in a "nick_change" event.

This key is only present in certain cases. See L</type> below.

=item * message

A human readable message with details of this event.

This key is only present in certain cases. See L</type> below.

=item * topic

See L<Convos::Core::Conversation/topic>.

This key is only present in certain cases. See L</type> below.

=item * type

Can be...

  Type         | Extra keys
  -------------|---------------------------------------
  me           | nick, ...
  frozen       | conversation_id, frozen, name, topic, unread
  join         | conversation_id, nick
  quit         | conversation_id, nick, message
  part         | conversation_id, nick, message
  part         | conversation_id, kicker, nick, message
  mode         | conversation_id, from, mode, nick
  nick_change  | new_nick, old_nick

=back

=head1 METHODS

=head2 start

Will push L<Convos::Core::User> and L<Convos::Core::Connection> events as JSON
objects over a WebSocket connection and receive messages from the frontend.

=head2 webhook

See L<https://convos.chat/api.html#op-post--webhook>

=head1 SEE ALSO

L<Convos>:

=cut
