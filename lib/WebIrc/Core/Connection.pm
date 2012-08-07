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
use Parse::IRC;
use Carp qw/croak/;
use constant DEBUG => $ENV{'WEBIRC_CONNECTION_DEBUG'} // 1; # default to true while developing

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

=head2 channels

IRC channels to join on connect

=cut

has 'channels';

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
    $redis->smembers("connection:$id:channels",sub {
      my ($redis,$channels)=@_;
      $self->channels($channels);
      $cb->($self);
    });
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
    for my $attr (@keys) {
      unless(defined $self->$attr) {
        warn sprintf "[connection:%s] Attribute '%s' is missing from config\n", $self->id, $attr;
        $self->add_message({
          prefix => 'internal',
          command => 'PRIVMSG',
          params => [ internal => "Attribute '$attr' is missing from config" ],
        });
        return;
      }
    }

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
            my $message=parse_irc($1);
            given($message->{command}) {
              when('001') {
                for my $channel (@{$self->channels}) {
                  $stream->write('JOIN '.$channel."\r\n");
                }
              }
              when('PRIVMSG') {
                $self->add_message($message);
              }
              when('PING') {
                $stream->write('PONG '.$message->{params}->[0].'\n\r');
              }
            }
            warn sprintf "[connection:%s] %s\n", $self->id, $message->{raw_line} if DEBUG;
          }
        });
        $stream->write('NICK '.$self->nick."\r\n");
        $stream->write('USER '.$self->user." 8 * :WiRC IRC Proxy\r\n");
      })
    });
}

sub add_message {
  my ($self,$message)=@_;
  $self->redis->rpush('connection:'.$self->id.':msg:'.$message->{params}->[0],$message->{params}->[1]);
  unless($message->{params}->[0] =~ /^\#/x) {
    $self->redis->sadd('connection:'.$self->id.':conversations',$message->{params}->[0]);
    #$self->redis->publish('connection:'.$self->id.':messages',$self->json); <-- $self->json?
  }
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
