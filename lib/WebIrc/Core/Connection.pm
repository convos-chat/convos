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
use IRC::Utils qw/decode_irc/;
use Carp qw/croak/;

my @keys=qw/nick user host port password ssl/;

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has 'redis';

=head2 id

Holds the id of this connection. This will be set by the C<$id> given to
L</load>.

=cut

has 'id';

=head2 user

IRC username

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

=cut

use Data::Dumper;
sub load {
  my ($self,$cb)=@_;
  return $cb->($self) if $self->{_loaded}++;
  my $delay;
  my $id=$self->id || croak "Cannot load connection without id";
  my @req= map { "connection:$id:$_" } @keys ;
  $self->redis->mget(@req, sub {
    my ($redis,$res)=@_;
    foreach my $key (@keys) {
      $self->$key(shift @$res);
    }
    $cb->($self);
  });
  return $self;
}

=head2 connect

  $self->connect;

Will login to the L</irc> server.

=cut

sub connect {
  my $self=shift;
  $self->load(sub {
    warn "Gonna connect to ".$self->host;
    Mojo::IOLoop->singleton->client(
      address=>$self->host,
      port=>$self->port, sub {
        my ($loop,$err,$stream)=@_;
        $stream->timeout(300);
        $self->stream($stream);
        my $buffer='';
        $stream->on( read => sub {
          my ($stream,$chunk)=@_;
          $buffer .= $chunk;
          while( $buffer =~ s/^([^\r\n]+)\r\n//s) {
            warn decode_irc($1);
          }
        });
        $stream->write('NICK '.$self->nick."\r\n");
        $stream->write('USER '.$self->user." 8 * :WiRC IRC Proxy\r\n");
        })
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
