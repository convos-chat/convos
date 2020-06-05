package Convos::Util;
use Mojo::Base 'Exporter';

use JSON::Validator::Error;
use Mojo::Collection 'c';
use Mojo::File;
use Mojo::Util qw(b64_decode b64_encode md5_sum monkey_patch);
use Time::Piece ();

use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

our $CHANNEL_RE = qr{[#&]};
our @EXPORT_OK  = (
  qw($CHANNEL_RE DEBUG E has_many pretty_connection_name require_module),
  qw(sdp_decode sdp_encode short_checksum tp),
);

sub E {
  my ($msg, $path) = @_;
  $msg =~ s! at \S+.*!!s;
  $msg =~ s!:.*!.!s;
  return {errors => [JSON::Validator::Error->new($path, $msg)]};
}

sub has_many {
  my ($plural_accessor, $many_class, $constructor) = @_;
  my $class = caller;

  my $singular_accessor = $plural_accessor;
  $singular_accessor =~ s!s$!!;

  monkey_patch $class => $plural_accessor => sub {
    return c(values %{$_[0]->{$plural_accessor} || {}});
  };

  monkey_patch $class => "n_$plural_accessor" => sub {
    return int values %{$_[0]->{$plural_accessor} || {}};
  };

  monkey_patch $class => $singular_accessor => sub {
    my ($self, $attrs) = @_;
    my $id  = $many_class->id($attrs);
    my $obj = $self->{$plural_accessor}{$id} || $self->$constructor($attrs);
    map { $obj->{$_} = $attrs->{$_} } keys %$attrs if $self->{$plural_accessor}{$id};
    $self->{$plural_accessor}{$id} = $obj;
  };

  monkey_patch $class => "get_$singular_accessor" => sub {
    my ($self, $attrs) = @_;
    my $id = ref $attrs ? $attrs->{id} || $many_class->id($attrs) : $attrs;
    Carp::confess("Could not build 'id' for $class") unless defined $id;
    return $self->{$plural_accessor}{lc($id)};
  };

  my $remover = "remove_$singular_accessor";
  $class->can($remover) or monkey_patch $class => $remover => sub {
    my ($self, $attrs) = @_;
    my $id = lc(ref $attrs ? $attrs->{id} || $many_class->id($attrs) : $attrs);
    return delete $self->{$plural_accessor}{$id};
  };
}

sub pretty_connection_name {
  my $name = shift;

  return '' unless defined $name;
  return 'magnet' if $name =~ /\birc\.perl\.org\b/i;    # also match ssl.irc.perl.org
  return 'efnet'  if $name =~ /\befnet\b/i;

  $name = 'localhost' if $name eq '127.0.0.1';
  $name =~ s!^(irc|chat)\.!!;                           # remove common prefixes from server name
  $name =~ s!:\d+$!!;                                   # remove port
  $name =~ s!\.\w{2,3}$!!;                              # remove .com, .no, ...
  $name =~ s!\.chat$!!;
  $name =~ s![\W_]+!-!g;                                # make pretty url
  $name;
}

sub require_module {
  my $name        = pop;
  my $required_by = shift || caller;

  return $name if eval "require $name; 1";
  die <<"HERE";

  You need to install $name to use $required_by:

  \$ ./script/convos cpanm -n $name

HERE
}

sub sdp_decode {
  return join "\r\n", map {
    local $_ = "$_";
    s/^F!(.+)\s(.+)/{"a=fingerprint:$1 " . join ':', map {uc sprintf '%02x', ord $_} split '', b64_decode $2}/e;
    s/^I!/a=ice-/;
    s/^R!/a=rtpmap:/;
    s/^T!(\d+)/a=rtpmap:$1 telephone-event/;
    $_;
  } split(/\r?\n/, shift), '';
}

sub sdp_encode {
  return join "\n", map {
    s/a=fingerprint:(.+)\s(.+)/{"F!$1 " . b64_encode(join('', map {chr hex} split ':', $2), '')}/e;
    local $_ = "$_";
    s/^a=rtpmap:(\d+) telephone-event/T!$1/;
    s/^a=rtpmap:/R!/;
    s/^a=ice-/I!/;
    $_;
  } grep { !/^(?:a=ssrc|a=extmap:\d|a=fmtp:\d|a=rtcp-fb:\d)/ } split /\r?\n/, shift;
}

sub short_checksum {
  my $checksum = 32 == length $_[0] && $_[0] =~ /^[a-z0-9]{32}$/ ? shift : md5_sum shift;
  my $short    = b64_encode pack 'H*', $checksum;
  $short =~ s![eioEIO+=/\n]!!g;
  return substr $short, 0, 16;
}

sub tp {
  local $_ = shift;
  $_ =~ s!Z$!!;
  $_ =~ s!\.\d*$!!;
  Time::Piece->strptime($_, '%Y-%m-%dT%H:%M:%S');
}

1;

=encoding utf8

=head1 NAME

Convos::Util - Utility functions

=head1 SYNOPSIS

  package Convos::Core::Core;
  use Convos::Util qw(DEBUG has_many);

=head1 DESCRIPTION

L<Convos::Util> is a utily module for L<Convos>.

=head1 FUNCTIONS

=head2 has_many

  has_many $attribute => $many_class_class => sub {
    my ($obj, $attrs) = @_;
    return $many_class_class->new($attrs);
  };

Used to automatically define a create/update, get and list method to the
caller class. Example:

  has_many users => "Convos::Core::User" => sub {
    my ($obj, $attrs) = @_;
    return Convos::Core::User->new($attrs);
  };

The definition above results in the following methods:

  # Create or update and existing Convos::Core::User object
  $user = $class->user(\%attrs);

  # Retrieve a Convos::Core::User object or undef()
  $user = $class->get_user($id);
  $user = $class->get_user(\%attrs);

  # Retrieve an array-ref of Convos::Core::User objects
  $users = $class->users;

  # Remove a user
  $user = $class->remove_user($id);
  $user = $class->remove_user(\%attrs);

=head2 pretty_connection_name

  $str = pretty_connection_name($hostname);

Will turn a given hostname into a nicer connection name.

=head2 require_module

  require_module "Some::Module";

Will load the module or C<die()> with a message for how to install it.

=head2 sdp_decode

  $sdp = sdp_decode "v=0\n...";

Used to decode the C<$sdp> created by L</sdp_encode>.

=head2 sdp_encode

  $sdp = sdp_encode "v=0\r\n...";

Will filter and compress a SDP message.

=head2 tp

  $tp = tp "2020-06-09T02:39:51";
  $tp = tp "2020-06-09T02:39:51Z";
  $tp = tp "2020-06-09T02:39:51.001Z";

Used to create a L<Time::Piece> object from a date-time string.

=head2 short_checksum

  $str = short_checksum($md5_sum);

Will take a MD5 or SHA1 string and shorten it.

  # "7Mvfktc4v4MZ8q68"
  short_checksum "eccbc87e4b5ce2fe28308fd9f2a7baf3";

=head1 SEE ALSO

L<Convos>.

=cut
