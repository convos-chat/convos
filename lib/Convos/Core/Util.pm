package Convos::Core::Util;

=head1 NAME

Convos::Core::Util - Utility functions for Convos

=head1 SYNOPSIS

L</import> can export any of the L</FUNCTIONS>.

=cut

use Mojo::Base 'Exporter';

our @EXPORT_OK = ( qw(as_id id_as hostname logf format_time) );

no warnings "utf8";
use Mojo::Log;
use Mojo::UserAgent;
use Parse::IRC ();
use Unicode::UTF8;
use Time::Piece;

my $hostname;

our $SERVER_NAME_RE = qr{(?:\w+\.[^:/]+|localhost|loopback):?\d*};

=head1 FUNCTIONS

=head2 as_id

    $id = as_id @str;

This method will convert the input to a string which can be used as id
attribute in your HTML doc.

It will convert non-word characters to ":hex" and join C<@str> with ":00".

=cut

sub as_id {
  join ':00', map {
    local $_ = $_; # local $_ is for changing constants and not changing input
    s/:/:3a/g;
    s/([^\w:])/{ sprintf ':%02x', ord $1 }/ge;
    $_;
  } grep {
    length $_;
  } @_;
}

=head2 id_as

    @str = id_as $id;

Reverse of L</as_id>.

=cut

sub id_as {
  map {
    s/:(\w\w)/{ chr hex $1 }/ge;
    $_;
  } split /:00/, $_[0];
}

=head2 hostname

  $hostname = hostname();

Returns the public domain name for the current hostname or fall back on "localhost".

=cut

sub hostname {
  $hostname ||= do {
    use IO::Socket::INET;
    use Socket;
    $ENV{PUBLIC_IP} ||= Mojo::UserAgent->new->get('http://icanhazip.com')->res->body;
    $ENV{PUBLIC_IP} =~ s/\s//g;
    +(gethostbyaddr inet_aton($ENV{PUBLIC_IP}), AF_INET)[0] || 'localhost';
  };
}

=head2 logf

  $c->logf($level => $format, @args);
  $c->logf(debug => 'yay %s', \%data);

Used to log more complex datastructures and to prevent logging C<undef>.

=cut

sub logf {
  use Data::Dumper;
  my($self, $level, $format, @args) = @_;
  my $log = $self->{app}{log} || $self->{log} || Mojo::Log->new;

  local $Data::Dumper::Maxdepth = 2;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Terse = 1;

  for my $arg (@args) {
    if(ref($arg) =~ /^\w+$/) {
      $arg = Dumper($arg);
    }
    elsif(!defined $arg) {
      $arg = '__UNDEF__';
    }
  }

  $log->$level(sprintf $format, @args);
}

=head2 format_time

  $str = format_time $timestamp, $format;

=cut

sub format_time {
  my $date = localtime shift;
  my $format = shift;

  return $date->strftime($format);
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
