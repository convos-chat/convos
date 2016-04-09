package Convos::Core::Connection;
use Mojo::Base 'Mojo::EventEmitter';

use Convos::Core::Dialog;
use Convos::Util 'has_many';
use Mojo::Loader 'load_class';
use Mojo::URL;

sub name { shift->{name} }
sub protocol { shift->{protocol} || 'null' }

sub url {
  return $_[0]->{url} if ref $_[0]->{url};
  return $_[0]->{url} = Mojo::URL->new($_[0]->{url} || '');
}

sub user { shift->{user} }

sub connect {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "connect" not implemented.');
}

has_many dialogs => 'Convos::Core::Dialog' => sub {
  my ($self, $attrs) = @_;
  my $dialog = Convos::Core::Dialog->new($attrs);
  Scalar::Util::weaken($dialog->{connection} = $self);
  return $dialog;
};

sub disconnect {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "disconnect" not implemented.');
}

sub id {
  return lc join '-', @{$_[1]}{qw(protocol name)} if $_[1];
  return lc join '-', @{$_[0]}{qw(protocol name)};
}

sub new {
  my $self = shift->SUPER::new(@_);
  $self->dialog($_) for @{delete($self->{dialogs}) || []};
  $self;
}

sub participants {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "participants" not implemented.', []);
}

sub rooms {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "rooms" not implemented.', []);
}

sub save {
  my $self = shift;
  $self->user->core->backend->save_object($self, @_);
  $self;
}

sub send {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "send" not implemented.', undef);
}

sub state {
  my ($self, $state, $message) = @_;
  my $old_state = $self->{state} || '';
  return $self->{state} ||= 'queued' unless $state;
  die "Invalid state: $state" unless grep { $state eq $_ } qw(connected queued disconnected);
  $self->emit(state => connection => {state => $state, message => $message // ''})
    unless $old_state eq $state;
  $self->{state} = $state;
  $self;
}

sub _next_tick {
  my ($self, $method, @args) = @_;
  Mojo::IOLoop->next_tick(sub { $self->$method(@args) });
  $self;
}

sub _userinfo {
  my $self = shift;
  my @userinfo = split /:/, $self->url->userinfo // '';
  $userinfo[0] ||= $self->user->email =~ /([^@]+)/ ? $1 : '';
  $userinfo[1] ||= undef;
  return \@userinfo;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  $self->{state} ||= 'queued';
  my $json = {map { ($_, '' . $self->$_) } qw(id name protocol state url)};

  $json->{state} = 'queued' if $persist and $json->{state} eq 'connected';

  if ($persist) {
    $json->{dialogs} = [map { $_->TO_JSON($persist) } @{$self->dialogs}];
  }

  $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Connection - A Convos connection base class

=head1 DESCRIPTION

L<Convos::Core::Connection> is a base class for L<Convos> connections.

See also L<Convos::Core::Connection::Irc>.

=head1 EVENTS

=head2 dialog

  $self->on(dialog => sub { my ($self, $dialog) = @_; });

Emitted when a new L<$dialog|Convos::Core::Dialog> is created.

=head2 me

  $self->on(me => sub { my ($self, $me) = @_; });

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

  $self->on(message => sub { my ($self, $self, $msg) = @_; });
  $self->on(message => sub { my ($self, $dialog, $msg) = @_; });

Emitted when a connection or dialog receives a new message. C<$msg>
will contain:

  {
    from    => $str,
    message => $str,
    type    => {action|notice|privmsg},
  }

=head2 state

  $self->on(state => sub { my ($self, $state, $reason) = @_; });

Emitted when the connection state change.

=head2 dialog

  $self->on(dialog => sub { my ($self, $dialog, $info) = @_; });

Emitted when the dialog change state. C<$info> will contain information about
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

  $str = $self->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a connection.

=head2 name

  $str = $self->name;

Holds the name of the connection.

=head2 protocol

  $str = $self->protocol;

Holds the protocol name.

=head2 url

  $url = $self->url;

Holds a L<Mojo::URL> object which describes where to connect to. This
attribute is read-only.

=head2 user

  $user = $self->user;

Holds a L<Convos::Core::User> object that owns this connection.

=head1 METHODS

L<Convos::Core::Connection> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connect

  $self = $self->connect(sub { my ($self, $err) = @_ });

Used to connect to L</url>. Meant to be overloaded in a subclass.

=head2 dialog

  $dialog = $self->dialog(\%attrs);

Returns a new L<Convos::Core::Dialog> object or updates an existing object.

=head2 dialogs

  $objs = $self->dialogs;

Returns an array-ref of of L<Convos::Core::Dialog> objects.

=head2 disconnect

  $self = $self->disconnect(sub { my ($self, $err) = @_ });

Used to disconnect from server. Meant to be overloaded in a subclass.

=head2 get_dialog

  $dialog = $self->get_dialog($id);
  $dialog = $self->get_dialog(\%attrs);

Returns a L<Convos::Core::Dialog> object or undef.

=head2 new

  $self = Convos::Core::Connection->new(\%attrs);

Creates a new connection object.

=head2 participants

  $self = $self->participants("#target" => sub { my ($self, $err, $participants) = @_; });

Retrieves a list of participants in a room.

=head2 rooms

  $self = $self->rooms(sub { my ($self, $err, $list) = @_; });

Used to retrieve a list of L<Convos::Core::Dialog> objects for the
given connection.

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 send

  $self = $self->send($target => $message, sub { my ($self, $err, $any) = @_; });

Used to send a C<$message> to C<$target>. C<$message> is a plain string and
C<$target> can be a user or room/channel name.

Meant to be overloaded in a subclass.

=head2 state

  $self = $self->state($state, $message);
  $state = $self->state;

Holds the state of this object. C<$state> can be "disconnected", "connected"
or "queued" (default). "queued" means that the object is in the
process of connecting or that it want to connect.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
