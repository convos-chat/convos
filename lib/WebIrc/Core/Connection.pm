package WebIrc::Core::Connection;

=head1 NAME

WebIrc::Core::Connection - Represents a connection to an IRC server

=head1 SYNOPSIS

  use WebIrc::Core::Connection;

  $c = WebIrc::Core::Connection->new(
          id => 'foobar',
          nick => 'coolnick',
          server => 'irc.perl.org',
        );

  $c = WebIrc::Core::Connection->new;
  $self->load('foobar');
  $self->connect;
  # ...
  $self->disconnect;

=cut

use Mojo::Base -base;
use Net::Async::IRC;
use IO::Async::Loop::Mojo;

my @keys=qw/user host port password ssl/;

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has 'redis';

=head2 irc

Holds a L<Net::Async::IRC> object.

=cut

has 'irc' => sub {
  my $loop = IO::Async::Loop::Mojo->new();
  my $irc=Net::Async::IRC->new(on_message_text=>sub {
      my ($this,$message,$hints)=@_;
    });
  $loop->add($irc);
  return $irc;
};

=head2 id

Holds the id of this connection. This will be set by the C<$id> given to
L</load>.

=cut

has 'id';

=head2 user

What is this? Is it realname?

=cut

has 'user';

=head2 host

IRC server hostname.

=cut

has 'host';

=head2 port

IRC server port. Defaults to 6667.

=cut

has 'port' => 6667;

=head2 password

IRC server password.

=cut

has 'password';

=head2 ssl

True if SSL should be used to connect to the IRC server.

=cut

has 'ssl' => sub { 0 };

=head2 nick

IRC server nickname.

=cut

has 'nick';

=head2 stream

Holds a L<Mojo::IOLoop::Stream> object?

=cut

has 'stream';

=head1 METHODS

=head2 load

  $self = $self->load($id, CODE);
  $self = $self->load($id);

Loads config from L</redis> and populates the L</ATTRIBUTES>
L</user>, L</host>, L</port>, L</password> and L</ssl>.

Will be called in blocking mode if C<CODE> is not present.

TODO: Can we remove blocking mode?

=cut

sub load {
  my ($self,$id,$cb)=@_;
  my $delay;
  $self->id($id);
  $self->redis->mget([ map { "connection:$id:$_" } @keys], sub {
    my ($redis,$res)=@_;
    foreach my $key (@keys) {
      $self->$key(pop @$res);
    }
    if($cb) {
      $cb->($self);
    }
  });
  return $self;
}

=head2 connect

  $self->connect;

Will login to the L</irc> server.

=cut

sub connect {
  my $self=shift;
  return if $self->irc->is_loggedin;
  $self->irc->login(
    nick      => $self->nick,
    host      => $self->host,
    service   => ( $self->port || 6667 ),
    pass      => $self->password,
    on_login  => sub {
      my $irc=shift;
      $irc->join()
    },
    on_error  => sub {
      my ($msg) =@_;
    # FIXME: handle errors here
  });
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  my $self = shift;
  $self->stream->write('QUIT');
  $self->stream->close;
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
