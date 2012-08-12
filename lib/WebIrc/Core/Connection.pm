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
use Mojo::JSON;
use IRC::Utils qw/decode_irc/;
use Parse::IRC;
use Carp qw/croak/;

# default to true while developing
use constant DEBUG => $ENV{'WEBIRC_CONNECTION_DEBUG'} // 1;

my @keys = qw/nick user host port password ssl/;

my $JSON = Mojo::JSON->new();

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

has 'ssl' => sub {0};

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

sub load {
  my ($self, $cb) = @_;
  return $cb->($self) if $self->{_loaded}++;
  my $delay;
  my $id = $self->id || croak "Cannot load connection without id";
  my @req = map {"connection:$id:$_"} @keys;
  $self->redis->mget(
    @req,
    sub {
      my ($redis, $res) = @_;
      foreach my $key (@keys) {
        $self->$key(shift @$res);
      }
      $redis->smembers(
        "connection:$id:channels",
        sub {
          my ($redis, $channels) = @_;
          $self->channels($channels);
          $cb->($self);
        }
      );
    }
  );
  return $self;
}

=head2 connect

  $self->connect;

Will login to the L</irc> server.

=cut

sub connect {
  my $self = shift;

  $self->load(
    sub {
      for my $attr (qw/ nick user host /) {
        unless (defined $self->$attr) {
          warn sprintf
            "[connection:%s] : Attribute '%s' is missing from config\n",
            $self->id, $attr;
          $self->add_message(internal =>
              [$self->nick => "Attribute '$attr' is missing from config"]);
          return;
        }
      }

      Mojo::IOLoop->singleton->client(
        address => $self->host,
        port    => $self->port,
        sub {
          my ($loop, $err, $stream) = @_;
          $stream->timeout(300);
          $self->stream($stream);
          my $buffer = '';
          $stream->on(
            read => sub {
              my ($stream, $chunk) = @_;
              $buffer .= $chunk;
              while ($buffer =~ s/^([^\r\n]+)\r\n//s) {
                warn sprintf "[connection:%s] > %s\n", $self->id, $1 if DEBUG;
                my $message = parse_irc($1);
                $message->{'command'} =
                  IRC::Utils::numeric_to_name($message->{'command'})
                  if $message->{'command'} =~ /^\d+$/;
                my $method = 'irc_' . lc $message->{'command'};
                if ($self->can($method)) {
                  $self->$method($message);
                }
                elsif (DEBUG) {
                  warn sprintf "[connection:%s] ! Cannot handle (%s)\n",
                    $self->id, $method
                    if DEBUG;
                }
              }
            }
          );
          $self->write(NICK => $self->nick);
          $self->write(USER => $self->user, 8, '*', ':WiRC IRC Proxy');
        }
      );
    }
  );
}

sub irc_privmsg {
  my ($self, $message) = @_;
  $self->add_message(privmsg => $message);
}

sub irc_mode {
  my ($self, $message) = @_;
  $self->redis->sadd(
    join(':', 'connection', $self->id, 'mode', $message->{params}->[0]),
    $message->{params}->[1]);
}

sub irc_notice {
  my ($self, $message) = @_;
  $self->add_message(notice => $message);
}

sub irc_err_nicknameinuse {    # 433
  my ($self, $message) = @_;

  $self->nick($self->nick . '_');
  $self->write(NICK => $self->nick);
}

sub irc_rpl_welcome {          # 001
  my ($self, $message) = @_;

  $self->nick($message->{params}->[0]);
  $self->redis->set(join(':', 'connection', $self->id, 'nick'),
    $message->{params}->[0]);

  for my $channel (@{$self->channels}) {
    $self->write(JOIN => $channel);
  }
}

sub irc_ping {
  my ($self, $message) = @_;
  $self->write(PONG => $message->{params}->[0]);
}

sub irc_rpl_yourhost {
} # :Tampa.FL.US.Undernet.org 002 batman__ :Your host is Tampa.FL.US.Undernet.org, running version u2.10.12.14

sub irc_rpl_created {
} # :Tampa.FL.US.Undernet.org 003 batman__ :This server was created Thu Jun 21 2012 at 01:26:15 UTC

sub irc_rpl_myinfo {
} # :Tampa.FL.US.Undernet.org 004 batman__ Tampa.FL.US.Undernet.org u2.10.12.14 dioswkgx biklmnopstvrDR bklov

sub irc_rpl_isupport {
} # :Tampa.FL.US.Undernet.org 005 batman__ WHOX WALLCHOPS WALLVOICES USERIP CPRIVMSG CNOTICE SILENCE=25 MODES=6 MAXCHANNELS=20 MAXBANS=50 NICKLEN=12 :are supported by this server

sub irc_rpl_luserclient {
} # :Tampa.FL.US.Undernet.org 251 batman__ :There are 3400 users and 46913 invisible on 18 servers

sub irc_rpl_luserop {
}    # :Tampa.FL.US.Undernet.org 252 batman__ 19 :operator(s) online

sub irc_rpl_luserunknown {
}    # :Tampa.FL.US.Undernet.org 253 batman__ 305 :unknown connection(s)

sub irc_rpl_luserchannels {
}    # :Tampa.FL.US.Undernet.org 254 batman__ 13700 :channels formed

sub irc_rpl_luserme {
} # :Tampa.FL.US.Undernet.org 255 batman__ :I have 12000 clients and 1 servers

sub irc_rpl_motdstart {
} # :Tampa.FL.US.Undernet.org 375 batman__ :- Tampa.FL.US.Undernet.org Message of the Day -

sub irc_rpl_motd {
} # :Tampa.FL.US.Undernet.org 372 batman__ :The message of the day was last changed: 2007-5-24 17:42

sub irc_rpl_endofmotd {
}    # :Tampa.FL.US.Undernet.org 376 batman__ :End of /MOTD command.

sub irc_error {
  my ($self, $message) = @_;

  if ($message->{params}->[0] =~ /Closing Link/) {
    $self->stream->close;
    $self->connect;
  }
}

sub add_message {
  my ($self, $type, $message) = @_;

  $self->redis->rpush(
    join(':', 'connection', $self->id, 'msg', $message->{params}->[0]),
    join(':', $type, time, $message->{params}->[1]),
  );

  unless ($message->{params}->[0] =~ /^\#/x) {
    $self->redis->sadd(join(':', 'connection', $self->id, 'conversations'),
      $message->{params}->[0]);
    $self->redis->publish(
      'connection:' . $self->id . ':messages',
      $JSON->encode({$type => $message})
    );
  }
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  my $self = shift;
  $self->write('QUIT');
  $self->stream->close;
}

=head2 write

  $self->write(@str);

C<@str> will be concatinated with " " and "\r\n" will be appended.

=cut

sub write {
  my $self = shift;
  my $buf = join ' ', @_;
  warn sprintf "[connection:%s] < %s\n", $self->id, $buf if DEBUG;
  $self->stream->write("$buf\r\n");
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
