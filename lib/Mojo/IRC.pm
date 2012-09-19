package Mojo::IRC;

=head1 NAME

Mojo::IRC - IRC Client for the Mojo IOLoop

=head1 SYNOPSIS

  my $irc = Mojo::IRC->new(
              nick => 'test123',
              user => 'my name',
              host => 'irc.perl.org',
            );

  $irc->on(join => sub {
      my($self, $message) = @_;
    warn "yay! i joined $message->{params}[0]";
  });

  $irc->on(privmsg => sub {
    my($self, $message) = @_;
    say $message->{prefix}, " said: ", $message->{params}[1];
  });

  $irc->connect(sub {
    my($irc, $err) = @_;
    return warn $err if $err;
    $irc->write(join => '#mojo');
  });

  Mojo::IOLoop->start;

=head1 DESCRIPTION

This class inherit from L<Mojo::EventEmitter>.

TODO:

  * Authentication with password
  * SSL
  * use IRC::Utils qw/ decode_irc /;

=head1 EVENTS

=head2 irc_close

  $self->$callback;

Called when the client has closed the connection.

=head2 irc_error

This event is used by IRC errors

=head2 error

Internal errors in the mojo ioloop

=head2 irc_err_nicknameinuse

=head2 irc_join

  $self->$callback({
    params => ['#html'],
    raw_line => ':somenick!~someuser@1.2.3.4 JOIN #html',
    command => 'JOIN',
    prefix => 'somenick!~someuser@1.2.3.4'
  });

=head2 irc_mode

  $self->$callback({
    params => ['somenick', '+i'],
    raw_line => ':somenick!~someuser@hostname.com MODE somenick :+i',
    command => 'MODE',
    prefix => 'somenick!~someuser@hostname.com'
  });

=head2 irc_notice

  $self->$callback({
    params => ['somenick', 'on 1 ca 1(4) ft 10(10)'],
    raw_line => ':Zurich.CH.EU.Undernet.Org NOTICE somenick :on 1 ca 1(4) ft 10(10)',
    command => 'NOTICE',
    prefix => 'Zurich.CH.EU.Undernet.Org',
  });

=head2 irc_ping

  $self->$callback({
    params => [2687237629],
    raw_line => 'PING :2687237629',
    command => 'PING',
  })

=head2 irc_privmsg

=head2 irc_rpl_created

  $self->$callback({
    params => ['somenick', 'This server was created Thu Jun 21 2012 at 01:26:15 UTC'],
    raw_line => ':Tampa.FL.US.Undernet.org 003 somenick :This server was created Thu Jun 21 2012 at 01:26:15 UTC',
    command => '003',
    prefix => 'Tampa.FL.US.Undernet.org'

  });

=head2 irc_rpl_endofmotd

=head2 irc_rpl_endofnames

  $self->$callback({
    params => ['somenick', '#channel', 'End of /NAMES list.'],
    raw_line => ':Budapest.Hu.Eu.Undernet.org 366 somenick #channel :End of /NAMES list.',
    command => '366',
    prefix => 'Budapest.Hu.Eu.Undernet.org'
  });

=head2 irc_rpl_isupport

  $self->$callback({
    params => ['somenick', 'WHOX', 'WALLCHOPS', 'WALLVOICES', 'USERIP', 'CPRIVMSG', 'CNOTICE', 'SILENCE=25', 'MODES=6', 'MAXCHANNELS=20', 'MAXBANS=50', 'NICKLEN=12', 'are supported by this server'],
    raw_line => ':Tampa.FL.US.Undernet.org 005 somenick WHOX WALLCHOPS WALLVOICES USERIP CPRIVMSG CNOTICE SILENCE=25 MODES=6 MAXCHANNELS=20 MAXBANS=50 NICKLEN=12 :are supported by this server',
    command => '005',
    prefix => 'Tampa.FL.US.Undernet.org'
  })

=head2 irc_rpl_luserchannels

  $self->$callback({
    params => ['somenick', '13700', 'channels formed'],
    raw_line => ':Tampa.FL.US.Undernet.org 254 somenick 13700 :channels formed',
    command => '254',
    prefix => 'Tampa.FL.US.Undernet.org'
  })

=head2 irc_rpl_luserclient

  $self->$callback({
    params => ['somenick', 'There are 3400 users and 46913 invisible on 18 servers'],
    raw_line => ':Tampa.FL.US.Undernet.org 251 somenick :There are 3400 users and 46913 invisible on 18 servers',
    command => '251',
    prefix => 'Tampa.FL.US.Undernet.org'
  });

=head2 rpl_luserme

  $self->$callback({
    params => ['somenick', 'I have 12000 clients and 1 servers'],
    raw_line => ':Tampa.FL.US.Undernet.org 255 somenick :I have 12000 clients and 1 servers',
    command => '255',
    prefix => 'Tampa.FL.US.Undernet.org'
  });

=head2 irc_rpl_luserop

  $self->$callback({
    params => ['somenick', '19', 'operator(s) online'],
    raw_line => ':Tampa.FL.US.Undernet.org 252 somenick 19 :operator(s) online',
    command => '252',
    prefix => 'Tampa.FL.US.Undernet.org'
  });

=head2 irc_rpl_luserunknown

  $self->$callback({
    params => ['somenick', '305', 'unknown connection(s)'],
    raw_line => ':Tampa.FL.US.Undernet.org 253 somenick 305 :unknown connection(s)',
    command => '253',
    prefix => 'Tampa.FL.US.Undernet.org'
  })

=head2 irc_rpl_motd

=head2 irc_rpl_motdstart

=head2 irc_rpl_myinfo

  $self->$callback({
    params => ['somenick', 'Tampa.FL.US.Undernet.org', 'u2.10.12.14', 'dioswkgx', 'biklmnopstvrDR', 'bklov'],
    raw_line => ':Tampa.FL.US.Undernet.org 004 somenick Tampa.FL.US.Undernet.org u2.10.12.14 dioswkgx biklmnopstvrDR bklov',
    command => '004',
    prefix => 'Tampa.FL.US.Undernet.org',
  })

=head2 irc_rpl_namreply

  $self->$callback({
    params => ['somenick', '=', '#html', 'somenick Indig0 Wildblue @HTML @CSS @Luch1an @Steaua_ Indig0_ Pilum @fade'],
    raw_line => ':Budapest.Hu.Eu.Undernet.org 353 somenick = #html :somenick Indig0 Wildblue @HTML @CSS @Luch1an @Steaua_ Indig0_ Pilum @fade',
    command => '353',
    prefix => 'Budapest.Hu.Eu.Undernet.org'
  })

=head2 irc_rpl_welcome

  $self->$callback({
    params => ['somenick', 'Welcome to the UnderNet IRC Network, somenick'],
    raw_line => ':Zurich.CH.EU.Undernet.Org 001 somenick :Welcome to the UnderNet IRC Network, somenick',
    command => '001',
    prefix => 'Zurich.CH.EU.Undernet.Org'
  })

=head2 irc_rpl_yourhost

  $self->$callback({
    params => ['somenick', 'Your host is Tampa.FL.US.Undernet.org, running version u2.10.12.14'],
    raw_line => ':Tampa.FL.US.Undernet.org 002 somenick :Your host is Tampa.FL.US.Undernet.org, running version u2.10.12.14',
    command => '002',
    prefix => 'Tampa.FL.US.Undernet.org'
  });

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use IRC::Utils;
use Parse::IRC;
use Scalar::Util 'weaken';
use constant DEBUG => $ENV{MOJO_IRC_DEBUG} ? 1 : 0;

my @DEFAULT_EVENTS = qw/ irc_ping irc_notice /;

=head1 ATTRIBUTES

=head2 nick

IRC server nickname.

=cut

has nick => '';

=head2 user

IRC username.

=cut

has user => '';

=head2 host

IRC server hostname.

=cut

has host => '';

=head2 name

The name of this IRC client. Defaults to "Mojo IRC".

=cut

has name => 'Mojo IRC';

=head1 METHODS

=head2 connect

  $self->connect(\&callback);

Will login to the IRC L</host> and call C<&callback> once connected or on error.
The callback receives a string describing the error if it fail and undef on
success.

=cut

sub connect {
  my ($self, $callback) = @_;
  my ($host, $port) = split /:/, $self->host;

  if ($self->{_stream}) {
    return $self->$callback(ref $self->{_stream} ? undef : $self->{_stream});
  }

  $self->register_default_event_handlers;

  weaken $self;
  Mojo::IOLoop->client(
    address => $host,
    port    => $port || 6667,
    sub {
      my ($loop, $err, $stream) = @_;
      my ($method, $message);
      my $buffer = '';

      $err and return $self->$callback($err);

      $stream->timeout(0);    # never time out
      $stream->on(
        close => sub {
          $self->emit('close');
          warn "Mojo::IRC::close\n" if DEBUG;
          delete $self->{_stream};
        }
      );
      $stream->on(
        error => sub {
          return if !$self;
          $self->emit(error => $_[1]);
          delete $self->{_stream};
        }
      );
      $stream->on(
        read => sub {
          #warn "Mojo::IRC::read($_[1])\n" if DEBUG;
          $buffer .= $_[1];

          while ($buffer =~ s/^([^\r\n]+)\r\n//m) {
            $message = parse_irc($1);
            $method = $message->{command} || '';

            if ($method =~ /^\d+$/) {
              $method = IRC::Utils::numeric_to_name($method);
            }

            $self->emit_safe(lc 'irc_'.$method => $message);
          }
        }
      );

      $self->{_stream} = $stream;
      $self->write(NICK => $self->nick);
      $self->write(USER => $self->user, 8, '*', ':'.$self->name);
      $self->$callback(undef);
    }
  );
}

=head2 disconnect

  $self->disconnect(\&callback);

Will disconnect form the server.

=cut

sub disconnect {
  my ($self, $cb) = @_;

  # already disconnected
  return $self->$cb unless $self->{_stream};

  # TODO: Figure out how this really works:
  # I think ->close will kill the connection at once and never fire the close
  # event...
  # I think you are right:
  # Event "irc_error" failed: Can't call method "once" on an undefined value at script/../lib/Mojo/IRC.pm line 345.
  $self->write('QUIT');
  $self->{_stream}->close;
  $self->{_stream}->once(close => $cb);
}

=head2 register_default_event_handlers

  $self->register_default_event_handlers;

This method sets up the default L</DEFAULT EVENT HANDLERS> unless someone has
already subscribed to the event.

=cut

sub register_default_event_handlers {
  my $self = shift;

  weaken $self;
  for my $event (@DEFAULT_EVENTS) {
    next if $self->has_subscribers($event);
    $self->on($event => $self->can($event));
  }
}

=head2 write

  $self->write(@str);

This method writes a message to the IRC server. C<@str> will be concatenated
with " " and "\r\n" will be appended.

=cut

sub write {
  my $self = shift;
  my $buf = join ' ', @_;
  warn "Mojo::IRC::write($buf)\n" if DEBUG;
  $self->{_stream}->write("$buf\r\n");
}

=head1 DEFAULT EVENT HANDLERS

=head2 irc_notice

Responds to the server with "QUOTE PASS ..." if the notice contains "Ident
broken...QUOTE PASS...".

=cut

sub irc_notice {
  my ($self, $message) = @_;

  # NOTICE AUTH :*** Ident broken or disabled, to continue to connect you must type /QUOTE PASS 21105
  if ($message->{'params'}[0] =~ m!/Ident broken.*QUOTE PASS (\S+)!) {
    $self->write(QUOTE => PASS => $1);
  }
}

=head2 irc_ping

Responds to the server with "PONG ...".

=cut

sub irc_ping {
  my ($self, $message) = @_;
  $self->write(PONG => $message->{params}->[0]);
}

=head2 irc_err_nicknameinuse

Tries to register with the same nick as L</nick>, only with an extra underscore
added. The new nick will be stored in L</nick>.

=cut

sub irc_err_nicknameinuse {
  my ($self, $message) = @_;

  $self->nick($self->nick . '_');
  $self->write(NICK => $self->nick);
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Marcus Ramberg - C<mramberg@cpan.org>

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
