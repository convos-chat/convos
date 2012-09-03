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
use constant STARTING => 's'; # doesn't really matter what this contains

# default to true while developing
use constant DEBUG => $ENV{'WIRC_DEBUG'} // 1;

my @keys = qw/nick user host password ssl/;

my $JSON = Mojo::JSON->new();

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object.

=cut

has redis => sub { Mojo::Redis->new };

=head2 id

Holds the id of this connection. This will be set by the C<$id> given to
L</load>.

=cut

has id => 0;

=head2 subscribe_id

id of messages subscription

=cut

has subscribe_id => 0;

=head2 user

IRC username

=cut

has user => '';

=head2 host

IRC server hostname.

=cut

has host => '';
has _real_host => '';

=head2 password

IRC server password.

=cut

has password => '';

=head2 ssl

True if SSL should be used to connect to the IRC server.

=cut

has ssl => 0;

=head2 nick

IRC server nickname.

=cut

has nick => '';

=head2 channels

IRC channels to join on connect

=cut

has channels => sub { [] };

# used to create redis keys
has _publish_key => sub { shift->{_key} .':from_server' };
has _key_prefix => sub { join ':', 'connection', $_[0]->id };
sub _key { join ':', shift->_key_prefix, @_ }
has _stream => undef;

=head1 METHODS

=head2 load

  $self = $self->load($id, CODE);
  $self = $self->load($id);

Loads config from L</redis> and populates the L</ATTRIBUTES>
L</user>, L</host>, L</password> and L</ssl>.

=cut

sub load {
  my ($self, $cb) = @_;
  return $cb->($self) if $self->{_loaded}++;
  my $id = $self->id || croak "Cannot load connection without id";
  my @req = map {"connection:$id:$_"} @keys;
  $self->redis->mget(@req, sub {
    my ($redis, $res) = @_;
    foreach my $key (@keys) {
      my $val = shift @$res;
      $self->$key($val) if defined $val;
    }
    $redis->smembers(
      "connection:$id:channels",
      sub {
        my ($redis, $channels) = @_;
        $self->channels($channels);
        $cb->($self);
      }
    );
  });
  return $self;
}

=head2 connect

  $self->connect;

Will login to the IRC L</<host>.

=cut

sub connect {
  my $self = shift;
  my($host, $port) = split /:/, $self->host;

  return $self if $self->_stream;
  $self->_stream(STARTING);
  $self->load(sub {
    warn sprintf "[connection:%s] : %s\n", $self->id, $self->host if DEBUG;
    Mojo::IOLoop->client(address => $host, port => $port || 6667, sub {
      my ($loop, $err, $stream) = @_;
      my $buffer = '';
      $stream->timeout(300);
      $stream->on(read => sub {
        my ($stream, $chunk) = @_;
        $buffer .= $chunk;
        while ($buffer =~ s/^([^\r\n]+)\r\n//s) {
          warn sprintf "[connection:%s] > %s\n", $self->id, $1 if DEBUG;
          my $message = parse_irc($1);
          if($message->{'command'} =~ /^\d+$/) {
              warn sprintf "[connection:%s] : Translating %s\n", $self->id, $message->{'command'} if DEBUG;
              $message->{'command'} = IRC::Utils::numeric_to_name($message->{'command'});
          }
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
      });
      $self->_stream($stream);
      $self->write(NICK => $self->nick);
      $self->write(USER => $self->user, 8, '*', ':WiRC IRC Proxy');
      $self->redis->del($self->_key('msg')); # want to load in new server messages
      $self->subscribe_id($self->redis->subscribe($self->_key('to_server'), sub {
        my ($redis,$res)=@_;
        # This also writes the elements below, which I'm not sure is the idea.
        # 0: subscribe
        # 1: connection:13:to_server
        # 2: 1
        #$self->write($_) for @$res;
      })) unless $self->subscribe_id;
    });
  });

  return $self;
}

=head2 irc_privmsg

=cut

sub irc_privmsg {
  my ($self, $message) = @_;
  $self->add_message($message);
}

=head2 irc_mode

Example message:

:somenick!~someuser@ti0034a380-dhcp0392.bb.online.no MODE somenick :+i

=cut

sub irc_mode {
}

=head2 irc_notice

Example message:

:Zurich.CH.EU.Undernet.Org NOTICE somenick :on 1 ca 1(4) ft 10(10)

=cut

sub irc_notice {
  my ($self, $message) = @_;

  # NOTICE AUTH :*** Ident broken or disabled, to continue to connect you must type /QUOTE PASS 21105
  if($message->{'params'}[0] =~ m!/Ident broken.*QUOTE PASS (\S+)!) {
    $self->write(QUOTE => PASS => $1);
  }
  else {
    $self->add_server_message($message);
  }
}

=head2 irc_err_nicknameinuse

=cut

sub irc_err_nicknameinuse {    # 433
  my ($self, $message) = @_;

  $self->nick($self->nick . '_');
  $self->write(NICK => $self->nick);
}

=head2 irc_rpl_welcome

Example message:

:Zurich.CH.EU.Undernet.Org 001 somenick :Welcome to the UnderNet IRC Network, somenick

=cut

sub irc_rpl_welcome {
  my ($self, $message) = @_;

  $self->_real_host($message->{prefix});
  $self->add_server_message($message);

  for my $channel (@{$self->channels}) {
    $self->write(JOIN => $channel);
  }
}

=head2 irc_ping

Example message:

PING :2687237629

=cut

sub irc_ping {
  my ($self, $message) = @_;
  $self->write(PONG => $message->{params}->[0]);
}

=head2 irc_rpl_yourhost

Example message:

:Tampa.FL.US.Undernet.org 002 somenick :Your host is Tampa.FL.US.Undernet.org, running version u2.10.12.14

=cut

sub irc_rpl_yourhost {
  $_[0]->add_server_message($_[1]);
}

=head2 irc_rpl_created

Example message:

:Tampa.FL.US.Undernet.org 003 somenick :This server was created Thu Jun 21 2012 at 01:26:15 UTC

=cut

sub irc_rpl_created {
  $_[0]->add_server_message($_[1]);
}

=head2 irc_rpl_myinfo

Example message:

:Tampa.FL.US.Undernet.org 004 somenick Tampa.FL.US.Undernet.org u2.10.12.14 dioswkgx biklmnopstvrDR bklov

=cut

sub irc_rpl_myinfo {
  my($self, $message) = @_;
  my @keys = qw/ nick real_host version available_user_modes available_channel_modes /;

  $self->nick($message->{params}[0]);

  while(my $key = shift @keys) {
    $self->redis->set($self->_key($key), shift @{ $message->{params} });
  }
}

=head2 irc_rpl_isupport

Example message:

:Tampa.FL.US.Undernet.org 005 somenick WHOX WALLCHOPS WALLVOICES USERIP CPRIVMSG CNOTICE SILENCE=25 MODES=6 MAXCHANNELS=20 MAXBANS=50 NICKLEN=12 :are supported by this server

=cut

sub irc_rpl_isupport {
}

=head2 irc_rpl_luserclient

Example message:

:Tampa.FL.US.Undernet.org 251 somenick :There are 3400 users and 46913 invisible on 18 servers

=cut

sub irc_rpl_luserclient {
}

=head2 irc_rpl_luserop

Example message:

:Tampa.FL.US.Undernet.org 252 somenick 19 :operator(s) online

=cut

sub irc_rpl_luserop {
}

=head2 irc_rpl_luserunknown

Example message:

:Tampa.FL.US.Undernet.org 253 somenick 305 :unknown connection(s)

=cut

sub irc_rpl_luserunknown {
}

=head2 irc_rpl_luserchannels

Example message:

:Tampa.FL.US.Undernet.org 254 somenick 13700 :channels formed

=cut

sub irc_rpl_luserchannels {
}

=head2 irc_rpl_luserme

Example message:

:Tampa.FL.US.Undernet.org 255 somenick :I have 12000 clients and 1 servers

=cut

sub irc_rpl_luserme {
}

=head2 irc_rpl_motdstart

:Tampa.FL.US.Undernet.org 375 somenick :- Tampa.FL.US.Undernet.org Message of the Day -

=cut

sub irc_rpl_motdstart {
  $_[0]->add_server_message($_[1]);
}

=head2 irc_rpl_motd

Example message:

:Tampa.FL.US.Undernet.org 372 somenick :The message of the day was last changed: 2007-5-24 17:42

=cut

sub irc_rpl_motd {
  $_[0]->add_server_message($_[1]);
}

=head2 irc_rpl_endofmotd

Example message:

:Tampa.FL.US.Undernet.org 376 somenick :End of /MOTD command.

=cut

sub irc_rpl_endofmotd {
  $_[0]->add_server_message($_[1]);
}

=head2 irc_join

Example message:

:somenick!~someuser@148.122.202.168 JOIN #html

=cut

sub irc_join {
  my($self, $message) = @_;

  $self->redis->publish($self->_publish_key, $JSON->encode({
    joined => $message->{params}[0],
    timestamp => time,
  }));
}

=head2 irc_rpl_namreply

Example message:

:Budapest.Hu.Eu.Undernet.org 353 somenick = #html :somenick Indig0 Wildblue @HTML @CSS @Luch1an @Steaua_ Indig0_ Pilum @fade

=cut

sub irc_rpl_namreply {
  my($self, $message) = @_;
  my @nicks = split /\s+/, $message->{params}[3]; # 3 = +nick0 @nick1, nick2

  $self->redis->sadd($self->_key('names', $message->{params}[2]), @nicks);
}

=head2 irc_rpl_endofnames

Example message:

:Budapest.Hu.Eu.Undernet.org 366 somenick #html :End of /NAMES list.

=cut

sub irc_rpl_endofnames {
}

=head2 irc_error

Example message:

ERROR :Closing Link: somenick by Tampa.FL.US.Undernet.org (Sorry, your connection class is full - try again later or try another server)

=cut

sub irc_error {
  my ($self, $message) = @_;

  $self->add_server_message($message);

  if ($message->{raw_line} =~ /Closing Link/i) {
    warn sprintf "[connection:%s] ! Closing link (reconnect)\n",
    $self->_stream->close;
    $self->connect;
  }
}

=head2 add_server_message

  $bool = $self->add_server_message(\%message);

Will look at L<%message> and add it to the database as a server message
if it looks like one. Returns true if the message was added to redis.

=cut

sub add_server_message {
  my($self, $message) = @_;
  my $time = time;

  if(!$message->{prefix} or $message->{prefix} eq $self->_real_host) {
    $self->redis->rpush(
      $self->_key('msg'),
      join("\0", $time, $self->host, $message->{params}[1] || $message->{params}[0]), # 1 = normal, 0 = error
    );
    $self->redis->publish($self->_publish_key, $JSON->encode({
      timestamp => $time,
      sender => $self->host,
      message => $message->{params}[1] || $message->{params}[0], # 1 = normal, 0 = error
      server => $self->host,
    }));
    return 1;
  }

  return;
}

=head2 add_message

  $self->add_message(\%message);

Will add a private message to the database.

=cut

sub add_message {
  my ($self, $message) = @_;
  my $time = time;

  $self->redis->rpush(
    $self->_key('msg', $message->{params}[0]),
    join("\0", $time, $message->{prefix}, $message->{params}[1]),
  );
  $self->redis->publish($self->_publish_key, $JSON->encode({
    timestamp => $time,
    server => $self->host,
    sender => $message->{prefix},
    target => $message->{params}[0],
    message => $message->{params}[1],
  }));

  unless ($message->{params}->[0] =~ /^\#/x) { # not a channel
    $self->redis->sadd($self->_key('conversations') => $message->{params}->[0]);
  }
}

=head2 disconnect

Will disconnect from the L</irc> server.

=cut

sub disconnect {
  my $self = shift;
  $self->write('QUIT');
  $self->_stream->close;
}

=head2 write

  $self->write(@str);

C<@str> will be concatinated with " " and "\r\n" will be appended.

=cut

sub write {
  my $self = shift;
  my $buf = join ' ', @_;
  warn sprintf "[connection:%s] < %s\n", $self->id, $buf if DEBUG;
  $self->_stream->write("$buf\r\n");
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
