package Convos::Core::Util;

=head1 NAME

Convos::Core::Util - Utility functions for Convos

=head1 SYNOPSIS

L</import> can export any of the L</FUNCTIONS>.

=cut

use Mojo::Base 'Exporter';

no warnings "utf8";
use Mojo::Log;
use Mojo::UserAgent;
use Parse::IRC ();
use Unicode::UTF8 'decode_utf8';
use Time::Piece;

our $SERVER_NAME_RE = qr{(?:\w+\.[^:/]+|localhost|loopback):?\d*};

our @EXPORT_OK = qw( as_id format_time id_as logf pretty_server_name $SERVER_NAME_RE );

=head1 FUNCTIONS

=head2 as_id

    $id = as_id @str;

This method will convert the input to a string which can be used as id
attribute in your HTML doc.

It will convert non-word characters to ":hex" and join C<@str> with ":00".

=cut

sub as_id {
  join ':00', map {
    local $_ = $_;    # local $_ is for changing constants and not changing input
    s/:/:3a/g;
    s/([^\w:-])/{ sprintf ':%02x', ord $1 }/ge;
    $_;
  } grep { length $_; } @_;
}

=head2 format_time

  $str = format_time $timestamp, $format;

=cut

sub format_time {
  my $date   = localtime shift;
  my $format = shift;

  return decode_utf8($date->strftime($format));
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

=head2 logf

  $c->logf($level => $format, @args);
  $c->logf(debug => 'yay %s', \%data);

Used to log more complex datastructures and to prevent logging C<undef>.

=cut

sub logf {
  use Data::Dumper;
  my ($self, $level, $format, @args) = @_;
  my $log = $self->{app}{log} || $self->{log} || Mojo::Log->new;

  local $Data::Dumper::Maxdepth = 2;
  local $Data::Dumper::Indent   = 0;
  local $Data::Dumper::Terse    = 1;

  for my $arg (@args) {
    if (ref($arg) =~ /^\w+$/) {
      $arg = Dumper($arg);
    }
    elsif (!defined $arg) {
      $arg = '__UNDEF__';
    }
  }

  $log->$level(sprintf $format, @args);
}

=head2 pretty_server_name

  $str = pretty_server_name($server);

Removes "ssl\.", "irc.", "chat." from the beginning and ".com", ".org", ...
from the end. Converts all non word and "_" to "-". Also removes the port.

Also has special handling for $servers matching...

  $server      | $str
  -------------|-------
  irc.perl.org | magnet
  efnet        | efnet

=cut

sub pretty_server_name {
  my ($name) = @_;

  return '' unless defined $name;
  return 'magnet' if $name =~ /\birc\.perl\.org\b/i;    # also match ssl.irc.perl.org
  return 'efnet'  if $name =~ /\befnet\b/i;

  $name =~ s!^(irc|chat)\.!!;                           # remove common prefixes from server name
  $name =~ s!:\d+$!!;                                   # remove port
  $name =~ s!\.\w{2,3}$!!;                              # remove .com, .no, ...
  $name =~ s![\W_]+!-!g;                                # make pretty url
  $name;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
