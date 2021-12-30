package Convos::Core::Connection;
use Mojo::Base 'Mojo::EventEmitter';

use Convos::Core::Conversation;
use Convos::Util qw(generate_cert_p get_cert_info has_many is_true logf pretty_connection_name);
use Convos::Util::Queue;
use Mojo::JSON qw(false true);
use Mojo::Loader qw(load_class);
use Mojo::Promise;
use Mojo::URL;
use Mojo::Util qw(term_escape url_escape);
use Unicode::UTF8;

use constant GENERATE_CERT => defined $ENV{CONVOS_GENERATE_CERT}
  ? is_true 'ENV:CONVOS_GENERATE_CERT'
  : 1;

$IO::Socket::SSL::DEBUG = $ENV{CONVOS_TLS_DEBUG} if $ENV{CONVOS_TLS_DEBUG};

has info => sub { +{} };

has messages => sub {
  my $self         = shift;
  my $conversation = Convos::Core::Conversation->new(id => '', name => $self->name);
  Scalar::Util::weaken($conversation->{connection} = $self);
  return $conversation;
};

has name                => sub { pretty_connection_name(shift->url->host) };
has on_connect_commands => sub { +[] };
has queue => sub { state $q = Convos::Util::Queue->new(delay => $ENV{CONVOS_CONNECT_DELAY} // 4) };

has profile => sub {
  my $self    = shift;
  my $profile = $self->user->core->connection_profile({url => $self->url});

  unless ($profile->url->host) {
    my $url = $self->url->clone->userinfo(undef);
    $profile->url($url->query(map { ($_ => $url->query->param($_)) } qw(tls tls_verify)));
  }

  return $profile;
};

has reconnect_delay => 0;

sub url {
  my ($self, $url) = @_;
  return $self->tap(sub { $self->{url} = ref $url ? $url : Mojo::URL->new($url) }) if @_ == 2;
  return $self->{url} = Mojo::URL->new($self->{url} || 'localhost') unless ref $self->{url};
  return $self->{url};
}

has wanted_state => 'connected';

sub user { shift->{user} }

sub connect_p {
  my $self = shift;

  my $state = $self->state;
  return Mojo::Promise->resolve                               if $state eq 'connected';
  return Mojo::Promise->reject(sprintf '%s.', ucfirst $state) if $state ne 'disconnected';
  return Mojo::Promise->reject('Does not want to be connected.')
    if $self->wanted_state ne 'connected';

  my $host       = $self->url->host;
  my $queue      = $self->queue;
  my $skip_queue = $self->profile->skip_queue;
  my $delay      = $skip_queue ? 0 : $queue->delay * $queue->size($host);

  $self->emit(state => frozen => $_->frozen('Not connected.')->TO_JSON)
    for grep { !$_->frozen } @{$self->conversations};

  $self->state(connecting => "Connecting to $host" . ($delay ? " in about ${delay}s." : "."));
  Scalar::Util::weaken($self);
  return $skip_queue
    ? $self->_connect_p
    : $queue->enqueue_p($host => sub { $self && $self->_connect_p });
}

has_many conversations => 'Convos::Core::Conversation' => sub {
  my ($self, $attrs) = @_;
  $attrs->{log} = $self->{log};
  my $conversation = Convos::Core::Conversation->new($attrs);
  Scalar::Util::weaken($conversation->{connection} = $self);
  return $conversation;
};

sub disconnect_p { shift->_stream_remove_p }

sub id {
  my $from = $_[1] || $_[0];
  return $from->{connection_id} ||= do {
    my $url = Mojo::URL->new($from->{url});
    join '-', $url->scheme, pretty_connection_name($url->host);
  };
}

sub new {
  my $self          = shift->SUPER::new(@_);
  my $conversations = delete $self->{conversations} || delete $self->{dialogs} || [];  # back compat
  $self->conversation($_) for @$conversations;
  $self->info->{authenticated} ||= false;
  $self->info->{capabilities}  ||= {};
  $self;
}

sub nick {
  my $self = shift;
  my $nick;
  return $nick if $nick = $self->info->{nick};
  return $nick if $nick = $self->url->query->param('nick');
  $nick = $self->user->email =~ /^([^@]+)/ ? $1 : 'guest';
  $nick =~ s!\W!_!g;
  return $nick;
}

sub reconnect_p {
  my $self = shift;
  return $self->disconnect_p->then(sub { $self->connect_p });
}

sub save_p {
  my $self = shift;
  return $self->user->core->backend->save_object_p($self, @_);
}

sub send_p { die 'Method "send_p" not implemented.' }

sub state {
  my ($self, $state, $message) = @_;
  $self->{state} ||= 'disconnected';

  # Get
  return $self->{state} if @_ == 1;

  # Set to same value
  return $self if $self->{state} eq $state;

  # Set to new value
  die "Invalid state: $state"
    unless grep { $state eq $_ } qw(connected connecting disconnected disconnecting);
  my $prev = $self->{state};
  $self->{state} = $state;

  if ($state eq 'disconnected' && $prev ne 'disconnecting' && $self->wanted_state eq 'connected') {
    $self->_reconnect_later_p;
    $message =~ s/([.!?]?)$/{($1 || '.') . " Reconnecting in $self->{reconnect_delay}s..."}/e;
  }

  if ($message) {
    $self->emit(state => connection => {state => $state, message => $message});
    $self->emit(
      message => $self->messages,
      {from => $self->id, highlight => false, message => $message, ts => time, type => 'notice'}
    );
  }

  $self->logf(
    debug => 'state = %s, wanted_state = %s (%s)',
    $state, $self->wanted_state, $message // ''
  );
  return $self;
}

sub uri { Mojo::Path->new(sprintf '%s/%s/connection.json', $_[0]->user->email, $_[0]->id) }

sub _connect_args_p {
  my $self   = shift;
  my $url    = $self->url;
  my $params = $url->query;

  my %args;
  $args{address} = $url->host;
  $args{socket_options}{LocalAddr} = $params->param('local_address')
    if $params->param('local_address');
  $args{port}    = $url->port;
  $args{timeout} = $ENV{CONVOS_CONNECT_TIMEOUT} || 20;

  $params->param(tls => 1)              unless defined $params->param('tls');
  return Mojo::Promise->resolve(\%args) unless $params->param('tls');

  $args{tls}                          = 1;
  $args{tls_ca}                       = $ENV{CONVOS_TLS_CA} if $ENV{CONVOS_TLS_CA};
  $args{tls_options}{SSL_verify_mode} = 0x00 unless $params->param('tls_verify');
  return Mojo::Promise->resolve(\%args) unless GENERATE_CERT;

  my $cert_dir = $self->user->core->home->child($self->user->email, $self->id);
  my $cert     = $cert_dir->child(sprintf '%s.cert', $self->id);
  my $key      = $cert_dir->child(sprintf '%s.key',  $self->id);

  if (-r $cert and -r $key) {
    @args{qw(tls_cert tls_key)} = map { $_->to_string } ($cert, $key);
    return Mojo::Promise->resolve(\%args);
  }

  $cert->dirname->make_path unless -d $cert->dirname;
  return generate_cert_p({cert => $cert, key => $key, email => $self->user->email})->then(sub {
    @args{qw(tls_cert tls_key)} = map { $_->to_string } ($cert, $key);
    return \%args;
  })->catch(sub {
    warn "Failed to generate cert: $_[0]";
    return \%args;
  });
}

sub _connect_args_to_info {
  my ($self, $connect_args) = @_;
  my $info = $self->info;

  $info->{socket}                = {};
  $info->{socket}{$_}            = $connect_args->{$_} for qw(address port timeout);
  $info->{socket}{tls}           = $connect_args->{tls} ? true : false;
  $info->{socket}{local_address} = $connect_args->{socket_options}{LocalAddr};
  $info->{certificate}{fingerprint}
    = $connect_args->{tls_cert} && get_cert_info(fingerprint => $connect_args->{tls_cert}) || '';
  $self->emit(state => info => $info);
}

sub _connect_p {
  my $self = shift;

  return $self->_connect_args_p->then(sub {
    my $connect_args = shift;
    return Mojo::Promise->reject(sprintf '%s.', $self->state) unless $self->state eq 'connecting';

    my $p = Mojo::Promise->new;
    $self->_connect_args_to_info($connect_args);
    $self->logf(debug => 'connect = %s', $connect_args);
    $self->{stream_id}
      = Mojo::IOLoop->client($connect_args, sub { $_[1] ? $p->reject($_[1]) : $p->resolve($_[2]) });

    return $p;
  })->then(sub {
    $self->_stream(shift);
  })->catch(sub {
    my $err = shift;
    Mojo::IOLoop->remove(delete $self->{stream_id}) if $self->{stream_id};

    my $q = $self->url->query;
    $q->param(tls => 0) if $q->param('tls') and ($err =~ /IO::Socket::SSL/ or $err =~ /SSL.*HELLO/);

    $self->state(disconnected => $err);
    return Mojo::Promise->reject($err);
  });
}

sub _notice {
  my ($self, $message) = (shift, shift);
  $self->emit(
    message => $self->messages,
    {from => $self->id, highlight => false, type => 'notice', @_, message => $message, ts => time},
  );
}

sub _reconnect_later_p {
  my $self = shift;
  $self->reconnect_delay($self->reconnect_delay ? $self->reconnect_delay * 2 : $self->queue->delay);
  $self->reconnect_delay(900) if $self->reconnect_delay > 900;    # TODO
  Scalar::Util::weaken($self);
  Mojo::Promise->timer($self->reconnect_delay)->then(sub { $self->connect_p })->catch(sub { });
}

sub _remove_conversation {
  my ($self, $name) = @_;
  my $conversation = $self->remove_conversation($name);
  $self->emit(state => part => {conversation_id => lc $name, nick => $self->nick});
  return $self;
}

sub _stream {
  my ($self, $stream) = @_;
  $self->{pid} //= $$;
  $self->{buffer} = '';
  $self->state(connected => "Connected to @{[$self->url->host]}.");

  Scalar::Util::weaken($self);
  Scalar::Util::weaken($self->{stream} = $stream);
  $stream->on(read    => sub { $self and $self->_stream_on_read(@_) });
  $stream->on(close   => sub { $self and $self->_stream_on_close(@_) });
  $stream->on(error   => sub { $self and $self->state(disconnected => $_[1]) });
  $stream->on(timeout => sub { $self and $self->state(disconnected => 'Connection timeout!') });
  $stream->timeout(0);
}

sub _stream_on_close {
  my ($self, $stream) = @_;
  return unless $self->{pid} == $$;
  delete @$self{qw(stream stream_id)};
  $self->state(disconnected => 'Connection closed.');
}

sub _stream_on_read {
  my ($self, $stream, $buf) = @_;
  die 'Method "_stream_on_read" not implemented.';
}

sub _stream_remove_p {
  my $self   = shift;
  my $stream = delete $self->{stream};
  $stream->close if $stream;
  $self->state(disconnected => 'Disconnected.');
  return Mojo::Promise->resolve({});
}

sub _write_p {
  my ($self, @data) = @_;

  my $buf = join ' ', @data;
  my $p   = Mojo::Promise->new;
  return $p->resolve({})              unless length $buf;
  return $p->reject('Not connected.') unless $self->{stream_id} and $self->{stream};

  $self->_write("$buf\r\n", sub { $p->resolve({}) });

  return $p;
}

sub _write {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $buf) = @_;

  unless ($self->{stream}) {
    Mojo::IOLoop->next_tick(sub { $self->$cb('Not connected.') }) if $cb;
    return;
  }

  $self->logf(trace => '<<< %s', term_escape $buf);
  $self->{stream}->write(Unicode::UTF8::encode_utf8($buf, sub { $_[0] }), $cb ? ($cb) : ());
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my $url  = $self->url;
  my %json = map { ($_, $self->$_) } qw(name on_connect_commands wanted_state);

  $json{connection_id}    = $self->id;
  $json{info}             = $self->info;
  $json{service_accounts} = $self->profile->service_accounts;
  $json{url}              = $url->to_unsafe_string;

  if (!$persist and $url->query->param('forced')) {
    my $password = $url->password // '';
    $json{url} =~ s!:$password\@!@!;
  }

  if ($persist) {
    $json{conversations} = [map { $_->TO_JSON($persist) } @{$self->conversations}];
  }
  else {
    $json{state} = $self->state;
  }

  return \%json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Connection - A Convos connection base class

=head1 DESCRIPTION

L<Convos::Core::Connection> is a base class for L<Convos> connections.

See also L<Convos::Core::Connection::Irc>.

=head1 EVENTS

=head2 conversation

  $conn->on(conversation => sub { my ($conn, $conversation) = @_; });

Emitted when a new L<$conversation|Convos::Core::Conversation> is created.

=head2 me

  $conn->on(me => sub { my ($conn, $me) = @_; });

Emitted when information about the representation of L</user> changes. C<$me>
contains:

  {
    nick                     => $str,
    real_host                => $str,
    version                  => $str,
    available_user_modes     => $str,
    available_channel_modes  => $str,
  }

Note that this hash is L<Convos::Core::Connection::Irc> specific.

=head2 message

  $conn->on(message => sub { my ($conn, $conn, $msg) = @_; });
  $conn->on(message => sub { my ($conn, $conversation, $msg) = @_; });

Emitted when a connection or conversation receives a new message. C<$msg>
will contain:

  {
    from    => $str,
    message => $str,
    type    => {action|error|notice|privmsg},
  }

=head2 state

  $conn->on(state => sub { my ($conn, $state, $reason) = @_; });

Emitted when the connection state change.

=head2 conversation

  $conn->on(conversation => sub { my ($conn, $conversation, $info) = @_; });

Emitted when the conversation change state. C<$info> will contain information about
the change:

  {join => $nick}
  {nick => $new_new, renamed_from => $old_nick_lc}
  {part => $nick, message => $reason, kicker => $kicker}
  {part => $nick, message => $reason}
  {updated => true}

=head1 ATTRIBUTES

L<Convos::Core::Connection> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 id

  $str = $conn->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a connection.

=head2 info

  $hash_ref = $conn->info;

Holds misc information about the connection.

=head2 messages

  $obj = $conn->messages;

Holds a L<Convos::Core::Conversation> object with the conversation to the server.

=head2 on_connect_commands

  $array_ref = $conn->on_connect_commands;
  $conn = $conn->on_connect_commands([...]);

Holds a list of commands to execute when first connected.

=head2 name

  $str = $conn->name;

Holds the name of the connection.

=head2 profile

  $profile = $conn->profile;
  $conn = $conn->profile(Convos::Core::ConnectionProfile->new);

Holds a L<Convos::Core::ConnectionProfile> object from
L<Convos::Core/connection_settings>.

=head2 reconnect_delay

  $num = $conn->reconnect_delay;
  $conn = $conn->reconnect_delay(4);

When the next automatic reconnect should happen after a failed L</connect_p>.

=head2 url

  $url = $conn->url;

Holds a L<Mojo::URL> object which describes where to connect to. This
attribute is read-only.

=head2 user

  $user = $conn->user;

Holds a L<Convos::Core::User> object that owns this connection.

=head2 wanted_state

  $conn = $conn->wanted_state("disconnected");
  $str = $conn->wanted_state;

Used to change the state that the user I<want> the connection to be in. Note
that it is also required to call L</connect_p> and L</disconnect> to actually
change the state.

=head1 METHODS

L<Convos::Core::Connection> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connect_p

  $p = $conn->connect_p;

Used to connect to L</url>. Meant to be overloaded in a subclass.

=head2 conversation

  $conversation = $conn->conversation(\%attrs);

Returns a new L<Convos::Core::Conversation> object or updates an existing object.

=head2 conversations

  $objs = $conn->conversations;

Returns an array-ref of of L<Convos::Core::Conversation> objects.

=head2 disconnect_p

  $p = $conn->disconnect_p;

Used to disconnect from server. Meant to be overloaded in a subclass.

=head2 get_conversation

  $conversation = $conn->get_conversation($id);
  $conversation = $conn->get_conversation(\%attrs);

Returns a L<Convos::Core::Conversation> object or undef.

=head2 new

  $conn = Convos::Core::Connection->new(\%attrs);

Creates a new connection object.

=head2 nick

  $str = $connection->nick;

Returns the current nick.

=head2 reconnect_p

  $p = $connection->reconnect_p;

Same as calling L</disconnect_p> and then L</connect_p>.

=head2 save_p

  $p = $conn->save_p->then(sub { my $conn = shift });

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 send_p

  $p = $conn->send_p($target => $message);

Used to send a C<$message> to C<$target>. C<$message> is a plain string and
C<$target> can be a user or room/channel name.

Meant to be overloaded in a subclass.

=head2 state

  $conn = $conn->state($state, $message);
  $state = $conn->state;

Holds the state of this object. C<$state> can be "disconnecting",
"disconnected", "connecting" or "connected".

=head2 uri

  $path = $conn->uri;

Holds a L<Mojo::Path> object, with the URI to where this object should be
stored.

=head1 SEE ALSO

L<Convos::Core>.

=cut
