package Convos::Core::Connection;

=head1 NAME

Convos::Core::Connection - A Convos connection base class

=head1 DESCRIPTION

L<Convos::Core::Connection> is a base class for L<Convos> connections.

See also L<Convos::Core::Connection::Irc>.

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Loader 'load_class';
use Mojo::URL;
use Convos::Core::Conversation::Direct;
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

=head1 EVENTS

=head2 conversation

  $self->on(conversation => sub { my ($self, $conversation) = @_; });

Emitted when a new L<$conversation|Convos::Core::Conversation> is created.

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
  $self->on(message => sub { my ($self, $conversation, $msg) = @_; });

Emitted when a connection or conversation receives a new message. C<$msg>
will contain:

  {
    from      => $str,
    highlight => $bool,
    message   => $str,
    type      => {action|notice|privmsg},
  }

=head2 state

  $self->on(state => sub { my ($self, $state, $reason) = @_; });

Emitted when the connection state change.

=head2 users

  $self->on(state => sub { my ($self, $conversation, $meta) = @_; });

Emitted when the list of users change in a conversation. C<$meta> will contain
information about the change:

  {join => $nick}
  {nick => $new_new, renamed_from => $old_nick_lc}
  {part => $nick, message => $reason, kicker => $kicker}
  {part => $nick, message => $reason}
  {updated => true}

=head1 ATTRIBUTES

L<Convos::Core::Connection> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

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

=cut

sub name { shift->{name} or die 'name is required in constructor' }

has protocol => sub {
  my $proto = substr ref($_[0]), length __PACKAGE__;
  $proto =~ s!^\W+!!;    # remove ::
  Mojo::Util::decamelize($proto);
};

sub url {
  return $_[0]->{url} if ref $_[0]->{url};
  return $_[0]->{url} = Mojo::URL->new($_[0]->{url} || '');
}

has user => sub { die 'user is required' };

=head1 METHODS

L<Convos::Core::Connection> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connect

  $self = $self->connect(sub { my ($self, $err) = @_ });

Used to connect to L</url>. Meant to be overloaded in a subclass.

=cut

sub connect { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "connect" not implemented.'); }

=head2 conversation

  $conversation = $self->conversation($id);            # get
  $conversation = $self->conversation($id => \%attrs); # create/update

Will return a L<Convos::Core::Conversation> object, identified by C<$id>.

=cut

sub conversation {
  my ($self, $id, $attr) = @_;

  if ($attr) {
    my $conversation = $self->{conversations}{$id} ||= do {
      my $conversation = $self->_conversation({connection => $self, id => $id});
      Scalar::Util::weaken($conversation->{connection});
      warn "[Convos::Core::User] Emit conversation: id=$id\n" if DEBUG;
      $self->emit(conversation => $conversation);
      $conversation;
    };
    $conversation->{$_} = $attr->{$_} for keys %$attr;
    return $conversation;
  }
  else {
    return $self->{conversations}{$id} || $self->_conversation({connection => $self, id => $id});
  }
}

=head2 conversations

  $objs = $self->conversations;

Returns an array-ref of of L<Convos::Core::Conversation> objects.

=cut

sub conversations {
  my $self = shift;
  return [values %{$self->{conversations} || {}}];
}

=head2 disconnect

  $self = $self->disconnect(sub { my ($self, $err) = @_ });

Used to disconnect from server. Meant to be overloaded in a subclass.

=cut

sub disconnect { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "disconnect" not implemented.'); }

=head2 join_conversation

  $self = $self->join_conversation("#some_channel", sub { my ($self, $err) = @_; });

Used to create a new conversation. See also L</conversation> event.

=cut

sub join_conversation {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, 'Method "join_conversation" not implemented.');
}

=head2 load

  $self = $self->load(sub { my ($self, $err) = @_; });

Will load L</ATTRIBUTES> from persistent storage.
See L<Convos::Core::Backend/load_object> for details.

=cut

sub load {
  my $self = shift;
  $self->user->core->backend->load_object($self, @_);
  $self;
}

=head2 rooms

  $self = $self->rooms(sub { my ($self, $err, $list) = @_; });

Used to retrieve a list of L<Convos::Core::Conversation::Room> objects for the
given connection.

=cut

sub rooms { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "rooms" not implemented.', []); }

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=cut

sub save {
  my $self = shift;
  $self->user->core->backend->save_object($self, @_);
  $self;
}

=head2 send

  $self = $self->send($target => $message, sub { my ($self, $err) = @_; });

Used to send a C<$message> to C<$target>. C<$message> is a plain string and
C<$target> can be a user or room/channel name.

Meant to be overloaded in a subclass.

=cut

sub send { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "send" not implemented.') }

=head2 state

  $self = $self->state($state, $description);
  $state = $self->state;

Holds the state of this object. C<$state> can be "disconnected", "connected"
or "connecting" (default). "connecting" means that the object is in the
process of connecting or that it want to connect.

=cut

sub state {
  my ($self, $state, $description) = @_;
  my $old_state = $self->{state} || '';
  return $self->{state} ||= 'connecting' unless $state;
  die "Invalid state: $state" unless grep { $state eq $_ } qw( connected connecting disconnected );
  $self->emit(state => $state => $description // '') unless $old_state eq $state;
  $self->{state} = $state;
  $self;
}

=head2 topic

  $self = $self->topic($conversation, sub { my ($self, $err, $topic) = @_; });
  $self = $self->topic($conversation => $topic, sub { my ($self, $err) = @_; });

Used to retrieve or set topic for a conversation.

=cut

sub topic { my ($self, $cb) = (shift, pop); $self->tap($cb, 'Method "topic" not implemented.') }

sub _conversation {
  my ($self, $c) = @_;
  die 'Cannot create conversation without class' unless $c->{class};
  my $e = load_class $c->{class};
  die $e || "Not found: $c->{class}" if $e;
  (delete $c->{class})->new($c);
}

sub _userinfo {
  my $self = shift;
  my @userinfo = split /:/, $self->url->userinfo // '';
  $userinfo[0] ||= $self->user->email =~ /([^@]+)/ ? $1 : '';
  $userinfo[1] ||= undef;
  return \@userinfo;
}

sub INFLATE {
  my ($self, $attrs) = @_;
  $self->conversation($_->{id}, $_) for @{delete($attrs->{conversations}) || []};
  $self->{$_} = $attrs->{$_} for keys %$attrs;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  $self->{state} ||= 'connecting';
  my $json = {map { ($_, '' . $self->$_) } qw( name state url )};

  $json->{state} = 'connecting' if $persist and $json->{state} eq 'connected';

  if ($persist) {
    $json->{conversations} = [];
    for my $conversation (values %{$self->{conversations} || {}}) {
      next unless $conversation->active;
      push @{$json->{conversations}}, $conversation->TO_JSON($persist);
    }
  }

  $json;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
