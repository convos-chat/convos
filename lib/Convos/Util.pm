package Convos::Util;
use Mojo::Base 'Exporter';

use Carp ();
use Mojo::Collection qw(c);
use Mojo::File qw(path);
use Mojo::URL;
use Mojo::IOLoop;
use Mojo::Util qw(b64_decode b64_encode monkey_patch sha1_sum);
use Sys::Hostname ();
use Time::HiRes   ();
use Scalar::Util qw(blessed);

$ENV{OPENSSL_BIN}      ||= 'openssl';
$ENV{CONVOS_LOG_LEVEL} ||= $ENV{MOJO_LOG_LEVEL} || ($ENV{HARNESS_IS_VERBOSE} ? 'trace' : 'error');

our $CHANNEL_RE = qr{[#&]};
our @EXPORT_OK  = (
  qw($CHANNEL_RE disk_usage generate_cert_p get_cert_info generate_secret),
  qw(has_many is_true logf pretty_connection_name require_module short_checksum yaml),
);

sub disk_usage {
  my $path = shift;
  state $df_bin = $ENV{CONVOS_DF_BINARY} || (-x '/bin/df' ? '/bin/df' : 'df');
  state $key    = sub { s!^i!! ? "inodes_$_" : "blocks_$_" };

  local $! = 1;
  my %usage;
  for my $opt ('', '-i') {
    next unless open my $DF, '-|', $df_bin => $opt ? ($opt) : () => $path;
    my $heading = readline $DF;
    my @stats   = split /\s+/, readline $DF;
    my @heading
      = $heading =~ m!\bused.*iused!i ? qw(skip used free skip iused ifree)
      : $opt eq '-i'                  ? qw(itotal iused ifree)
      :                                 qw(total used free);

    $usage{dev}        = shift @stats;
    $usage{block_size} = $heading =~ /(\d+)-blocks/i ? $1 : 1024;
    $usage{$key->()}   = shift @stats || 0 for @heading;
    last if defined $usage{inodes_used};
  }

  delete $usage{blocks_skip};
  die "Couldn't get disk usage: $!" unless %usage;
  $usage{blocks_total} ||= $usage{blocks_used} + $usage{blocks_free};
  $usage{inodes_total} ||= $usage{inodes_used} + $usage{inodes_free};
  $usage{$_} = int $usage{$_} for grep { $_ ne 'dev' } keys %usage;
  return \%usage;
}

sub generate_cert_p {
  my %params = %{$_[0]};

  # defaults
  $ENV{OPENSSL_BITS}         ||= 4096;
  $ENV{OPENSSL_COUNTRY}      ||= 'NO';
  $ENV{OPENSSL_DAYS}         ||= 3650;
  $ENV{OPENSSL_ORGANIZATION} ||= 'Convos';

  $params{$_} ||= $ENV{uc("OPENSSL_$_")} for qw(bits country days organization);
  $params{common_name} ||= $params{email} =~ m!^([^@]+)! ? $1 : $params{email};

  my @openssl = (qw(req -x509 -new -newkey));
  push @openssl, sprintf 'rsa:%s', $params{bits};
  push @openssl, qw(-sha256 -nodes);
  push @openssl, -days => $params{days}, -out => $params{cert}, -keyout => $params{key};
  push @openssl,
    -subj => sprintf '/C=%s/O=%s/CN=%s/emailAddress=%s',
    @params{qw(country organization common_name email)};

  return Mojo::IOLoop->subprocess->run_p(sub {
    open STDERR, '>', File::Spec->devnull;
    local ($!, $?);
    system $ENV{OPENSSL_BIN} => @openssl;
    die "$ENV{OPENSSL_BIN} @openssl FAIL $? / $!" if $? or $!;
    return \%params;
  });
}

sub get_cert_info {
  my ($what, $cert) = @_;
  return undef unless $cert and -r $cert;
  return undef unless $what eq 'fingerprint';

  my @openssl = (qw(x509 -noout -fingerprint -sha512 -in), $cert);
  my $fingerprint;
  open my $FH, '-|', $ENV{OPENSSL_BIN} => @openssl;
  /Fingerprint=(.*)/ && ($fingerprint = lc $1) while <$FH>;
  $fingerprint =~ s!:!!g if $fingerprint;
  return $fingerprint;
}

sub generate_secret {
  return eval { _generate_secret_urandom() } || _generate_secret_fallback();
}

sub has_many {
  my ($plural_accessor, $many_class, $constructor) = @_;
  my $class = caller;

  my $singular_accessor = $plural_accessor;
  $singular_accessor =~ s!s$!!;

  monkey_patch $class => $plural_accessor => sub {
    my $all = $_[0]->{$plural_accessor} || {};
    return c(map { $all->{$_} } sort keys %$all);
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

sub is_true {
  my $input = shift;
  my $val   = $input && $input =~ m!^ENV:(\w+)$! ? $ENV{$1} : $input;
  return undef  if !defined $val;
  return "$val" if blessed $val and $val->isa('JSON::PP::Boolean');
  return 0      if !$val or $val =~ /^(Off|No|false)$/i;
  return 1      if $val          =~ /^(1|On|Yes|true)$/i;

  my $name = $input =~ m!^ENV:([A-Z])$! ? $1 : 'Value';
  Carp::carp(qq($name should be 0, Off, No, false, 1, On, Yes or true, but is set to "$val".));
  return 0;
}

sub logf {
  my ($self, $level, $format, @args) = @_;
  my $log = $self->{log}
    //= Mojo::Log->new(level => $ENV{CONVOS_LOG_LEVEL})->context(sprintf '[fallback]');

  my $context = $self->{log_context} //= ($self->can('uri') ? $self->uri : ref $self);
  return $log->is_level($level) && $log->$level(
    sprintf "[%s] $format",
    $context,
    map {
      chomp;
      blessed $_ && $_->can('to_string') ? $_->to_string
        : ref $_                         ? Mojo::JSON::encode_json($_)
        : $_
    } @args
  );
}

sub pretty_connection_name {
  my $url = shift // '';
  $url = "irc://$url" unless blessed $url or $url =~ m!^\w+:!;
  $url = Mojo::URL->new($url);

  # Support ZNC style logins: <user>@<useragent>/<network>
  return $1 if +($url->username // '') =~ /^[a-z0-9_\+-]+@[a-z0-9_\+-]+\/([a-z0-9_\+-]+)/i;

  # Normalize hostname
  my $name = $url->host;
  return '' unless defined $name;
  return 'efnet'     if $name =~ /\befnet\b/i;
  return 'localhost' if $name eq '127.0.0.1';
  return 'magnet'    if $name =~ /\birc\.perl\.org\b/i;    # also match ssl.irc.perl.org

  $name =~ s!^(irc|chat)\.!!;                              # remove common prefixes from server name
  $name =~ s!:\d+$!!;                                      # remove port
  $name =~ s!\.\w{2,3}$!!;                                 # remove .com, .no, ...
  $name =~ s!\.chat$!!;
  $name =~ s![\W_]+!-!g;                                   # make pretty url

  return $name;
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

sub short_checksum {
  my $checksum = 40 == length $_[0] && $_[0] =~ /^[a-z0-9]{40}$/ ? shift : sha1_sum shift;
  my $short    = b64_encode pack 'H*', $checksum;
  $short =~ s![eioEIO+=/\n]!!g;
  return substr $short, 0, 16;
}

if (eval 'use YAML::XS 0.67;1') {
  *yaml = sub {
    local $YAML::XS::Boolean = 'JSON::PP';
    return $_[0] eq 'decode' ? YAML::XS::Load($_[1]) : YAML::XS::Dump($_[1]);
  };
}
else {
  require YAML::PP;
  my $pp = YAML::PP->new(boolean => 'JSON::PP');
  *yaml = sub {
    return $_[0] eq 'decode' ? $pp->load_string($_[1]) : $pp->dump_string($_[1]);
  };
}

sub _generate_secret_fallback {
  return sha1_sum join ':', rand(), $$, $<, Sys::Hostname::hostname(), Time::HiRes::time();
}

sub _generate_secret_urandom {
  my $len = shift || $ENV{CONVOS_SECRET_URANDOM_READ_LEN} || 128;
  open my $fh, '<', '/dev/urandom' or die "Can't open /dev/urandom: $!";
  my $ret = sysread $fh, my ($secret), $len;
  return sha1_sum $secret if $ret == $len;
  die qq{Could not read $len bytes from "/dev/urandom": $!};
}

1;

=encoding utf8

=head1 NAME

Convos::Util - Utility functions

=head1 SYNOPSIS

  package Convos::Core::Core;
  use Convos::Util qw(has_many);

=head1 DESCRIPTION

L<Convos::Util> is a utily module for L<Convos>.

=head1 FUNCTIONS

=head2 disk_usage

  $usage = disk_usage $device;
  $usage = disk_usage $path;

Returns the number of blocks and inodes for a device or path. Will throw an
exception if C<df> is not available. Example C<$usage>:

  {
    dev          => /dev/disk1s5,
    block_size   => 512,
    blocks_free  => 135681136,
    blocks_total => 157617272,
    blocks_used  => 21936136,
    inodes_free  => 4881965009,
    inodes_total => 4882452880,
    inodes_used  => 487871,
  }

=head2 generate_cert_p

  $p = generate_cert_p(\%params);

Used to generate an SSL cert and key file. Will use environment variables for
default values. C<%params> can contain:

=over 2

=item * bits

Default to C<$OPENSSL_BITS> or 4096.

=item * cert

Path to generated certificate file.

No default value.

=item * country

Default to C<$OPENSSL_COUNTRY> or emptry string.

=item * common_name

Default to the part before "@" in C<email>.

=item * days

Default to C<$OPENSSL_DAYS> or "3650".

=item * email

"emailAddress" in certificate subject.

No default value.

=item * key

Path to generated key file.

No default value.

=item * organization

Default to C<$OPENSSL_ORGANIZATION> or "Convos".

=back

=head2 generate_secret

  $str = generate_secret;

Returns a SHA1 sum of bytes from "/dev/urandom" or fallback to a SHA1 sum of:

    rand()     # Not cryptographically secure, but pseudo random
    $$         # Will probably be "1" inside Docker and probably less than 32768 on Linux
    $<         # Will probably be "0" inside Docker and probably less than 10000 on Linux
    hostname() # Will be unique inside Docker and guessable on Linux
    time()     # Floating seconds since the epoch (Ex: 1592094819.82439)

=head2 get_cert_info

  $fingerprint = get_cert_info fingerprint => $cert_file;

This function can be used to extract information about a certificate.
Rigth now onlye "fingerprint" is supported.

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

=head2 is_true

  $bool = is_true $any;
  $bool = is_true "ENV:NAME";

Checks if C<$any> or a given envirnment variable is either "0", "Off", "No",
"false", "1", "On", "Yes", "true" or a L<JSON::PP::Boolean> object and returns
the value.

Falls back to warn the user and return false.

=head2 logf

  $obj->logf($level => $format => @args);

Can be imported as a L<Mojo::Log> helper.

=head2 pretty_connection_name

  $str = pretty_connection_name($url);

Will turn a connection URL into a nicer connection name.

=head2 require_module

  require_module "Some::Module";

Will load the module or C<die()> with a message for how to install it.

=head2 short_checksum

  $str = short_checksum($sha1_sum);

Will take a MD5 or SHA1 string and shorten it.

  # "7Mvfktc4v4MZ8q68"
  short_checksum "77de68daecd823babbb58edb1c8e14d7106e83bb";

=head2 yaml

  $str  = yaml encode => \%data;
  $data = yaml decode => "---\nfoo: bar";

Utility function to parse or generate YAML, using either L<YAML::PP> or
L<YAML::XS>.

=head1 SEE ALSO

L<Convos>.

=cut
