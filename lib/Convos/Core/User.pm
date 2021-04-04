package Convos::Core::User;
use Mojo::Base 'Mojo::EventEmitter';

use Convos::Core::Connection;
use Convos::Util qw(DEBUG has_many);
use Crypt::Eksblowfish::Bcrypt ();
use File::Path                 ();
use Mojo::Date;
use Mojo::Promise;
use Mojo::Util qw(camelize trim);

use constant BCRYPT_BASE_SETTINGS => do {
  my $cost = sprintf '%02i', 8;
  my $nul  = 'a';
  join '', '$2', $nul, '$', $cost, '$';
};

sub core  { shift->{core}  or die 'core is required in constructor' }
sub email { shift->{email} or die 'email is required in constructor' }
has highlight_keywords => sub { +[] };
sub password { shift->{password} ||= '' }
has remote_address => '127.0.0.1';
sub registered { shift->{registered} ||= Mojo::Date->new }
has roles  => sub { +[] };
has uid    => sub { die 'uid() cannot be built' };
has unread => sub {0};

has_many connections => 'Convos::Core::Connection' => sub {
  my ($self, $attrs) = @_;
  my $connection_class = 'Convos::Core::Connection';

  if ($attrs->{connection_id}) {
    $connection_class = sprintf 'Convos::Core::Connection::%s',
      camelize(+(split '-', $attrs->{connection_id})[0]);
  }
  elsif ($attrs->{url}) {
    my $url = Mojo::URL->new($attrs->{url});
    $connection_class = sprintf 'Convos::Core::Connection::%s', camelize($url->scheme);
  }

  die qq($connection_class is not supported: $@)
    if !$connection_class->can('new')
    and !eval "require $connection_class;1";
  my $connection = $connection_class->new($attrs);
  Scalar::Util::weaken($connection->{user} = $self);
  warn "[@{[$self->email]}] Emit connection for id=@{[$connection->id]}\n" if DEBUG;
  $self->core->backend->emit(connection => $connection);
  return $connection;
};

sub get_p {
  my ($self, $args) = @_;
  my $res = $self->TO_JSON;

  my @connections;
  if ($args->{connections} or $args->{conversations}) {
    @connections = sort { $a->name cmp $b->name } @{$self->connections};
    $res->{connections} = \@connections;
  }

  if ($args->{conversations}) {
    $res->{conversations} = [sort { $a->id cmp $b->id } map { @{$_->conversations} } @connections];
  }

  # back compat - will be removed in future version
  my @p = map { $_->_calculate_unread_p } @{$res->{conversations} || []};

  return @p ? Mojo::Promise->all(@p)->then(sub {$res}) : Mojo::Promise->resolve($res);
}

sub role {
  my ($self, $action, $role) = @_;

  if ($action eq 'give') {
    my %roles = map { ($_ => 1) } @{$self->roles}, $role;
    return $self->roles([sort keys %roles]);
  }
  elsif ($action eq 'take') {
    return $self->roles([grep { $_ ne $role } @{$self->roles}]);
  }
  else {
    return !!grep { $_ eq $role } @{$self->roles};
  }
}

sub id { trim lc +($_[1] || $_[0])->{email} }

sub new {
  my $class = shift;
  my $self  = bless @_ ? @_ > 1 ? {@_} : {%{$_[0]}} : {}, ref $class || $class;
  return $self->_normalize_attributes;
}

sub notifications_p {
  my ($self, $query) = @_;
  return $self->core->backend->notifications_p($self, $query);
}

sub remove_connection_p {
  my ($self, $id) = @_;

  my $connection = Scalar::Util::blessed($id) ? $id : $self->{connections}{$id};
  return Mojo::Promise->resolve(undef) unless $connection;

  return $connection->disconnect_p->then(sub {
    return $self->core->backend->delete_object_p($connection);
  })->then(sub {
    delete $self->{connections}{$id};
    return $connection;
  });
}

sub save_p {
  my $self = shift;
  return $self->core->backend->save_object_p($self);
}

sub set_password {
  my ($self, $plain) = @_;
  die 'Usage: Convos::Core::User->set_password($plain)' unless $plain;
  $self->{password} = $self->_bcrypt($plain);
  $self;
}

sub uri { Mojo::Path->new(sprintf '%s/user.json', $_[0]->email) }

sub validate_password {
  my ($self, $plain) = @_;

  return 0 unless $self->password and $plain;
  return 1 if $self->_bcrypt($plain, $self->password) eq $self->password;
  return 0;
}

sub _bcrypt {
  my ($self, $plain, $settings) = @_;

  unless ($settings) {
    my $salt = join '', map { chr int rand 256 } 1 .. 16;
    $settings = BCRYPT_BASE_SETTINGS . Crypt::Eksblowfish::Bcrypt::en_base64($salt);
  }

  Crypt::Eksblowfish::Bcrypt::bcrypt($plain, $settings);
}

sub _normalize_attributes {
  my $self = shift;
  $self->{highlight_keywords} = [grep {/\w/} map { trim $_ } @{$self->{highlight_keywords} || []}];
  $self->{registered}         = $self->{registered}
    && !ref $self->{registered} ? Mojo::Date->new($self->{registered}) : Mojo::Date->new;
  return $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my $json = {map { ($_, $self->{$_} // '') } qw(email password)};
  delete $json->{password} unless $persist;
  $json->{highlight_keywords} = $self->highlight_keywords;
  $json->{registered}         = $self->registered->to_datetime;
  $json->{remote_address}     = $self->remote_address;
  $json->{roles}              = $self->roles;
  $json->{unread}             = $self->unread;
  $json->{uid}                = $self->uid;
  $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::User - A Convos user

=head1 DESCRIPTION

L<Convos::Core::User> is a class used to model a user in Convos.

=head1 ATTRIBUTES

L<Convos::Core::User> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head2 core

  $obj = $user->core;

Holds a L<Convos::Core> object.

=head2 email

  $str = $user->email;

Email address of user.

=head2 password

  $str = $user->password;

Encrypted password. See L</set_password> for how to change the password and
L</validate_password> for password authentication.

=head2 remote_address

  $str = $user->remote_address;
  $user = $user->remote_address('127.0.0.1');

Holds the last known remote address for the user.

=head2 roles

  $array_ref = $user->roles;

Holds a list of roles that the user has. See L</role> for changing this attribute.

=head2 uid

  $str = $user->uid;

Returns the UID for this user.

=head2 unread

  $int = $user->unread;
  $user = $user->unread(4);

Number of unread notifications for user.

=head2 uri

  $path = $user->uri;

Holds a L<Mojo::Path> object, with the URI to where this object should be
stored.

=head1 METHODS

L<Convos::Core::User> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 connection

  $connection = $user->connection(\%attrs);

Returns a new L<Convos::Core::Connection> object or updates an existing object.

=head2 connections

  $objs = $user->connections;

Returns an array-ref of of L<Convos::Core::Connection> objects.

=head2 get_connection

  $connection = $user->get_connection($id);
  $connection = $user->get_connection(\%attrs);

Returns a L<Convos::Core::Connection> object or undef.

=head2 get_p

  my $p = $user->get_p(\%args)->then(sub { my $json = shift });

Used to retrive information about the current user.

=head2 id

  $str = $user->id;
  $str = $class->id(\%attr);

Returns a unique identifier for a user.

=head2 new

  $user = Convos::Core::User->new(\%attributes);

Used to construct a new object.

=head2 notifications_p

  $p = $user->notifications_p($query)->then(sub { my $notifications = shift });

Used to retrieve a list of notifications. See also
L<Convos::Core::Backend/notifications>.

=head2 remove_connection_p

  $p = $user->remove_connection_p($connection)->then(sub { my $connection = shift });
  $p = $user->remove_connection_p($id)->then(sub { my $connection = shift });

Will remove a connection created by L</connection>. Removing a connection that
does not exist is perfectly valid, and will not result in a rejected promise.

=head2 registered

  $mojo_date = $user->registered;

Holds a L<Mojo::Date> object for when the user was registered.

=head2 role

  $bool = $user->role(has => "admin");
  $user = $user->role(give => "admin");
  $user = $user->role(take => "admin");

Used to modify L</roles> for a given user.

=head2 save_p

  $p = $user->save_p;

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 set_password

  $user = $user->set_password($plain);

Will set L</password> to a crypted version of C<$plain>.

=head2 validate_password

  $bool = $user->validate_password($plain);

Will verify C<$plain> text password against L</password>.

=head1 SEE ALSO

L<Convos::Core>.

=cut
