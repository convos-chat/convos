use Test::More;
use Convos::Util qw(generate_cert_p);
use Mojo::File qw(tempdir);

plan skip_all => "openssl: $!"
  unless do { open my $OPENSSL, '-|', $ENV{OPENSSL_BIN} => qw(version -a) };
delete $ENV{"OPENSSL_$_"} for qw(COUNTRY BITS DAYS ORGANIZATION STATE);

my $tmpdir = tempdir;

note 'generate with input';
generate_cert_p({
  bits         => 1024,
  cert         => $tmpdir->child('irc-convos.cert'),
  key          => $tmpdir->child('irc-convos.key'),
  common_name  => 'superwoman',
  country      => 'NO',
  days         => 7,
  email        => 'superwoman@convos.chat',
  organization => 'Convos',
  state        => 'Oslo',
})->wait;
test_cert(
  'irc-convos',
  {
    bits         => 1024,
    common_name  => 'superwoman',
    country      => 'NO',
    email        => 'superwoman@convos.chat',
    organization => 'Convos',
    state        => 'Oslo',
  }
);

note 'test that defaults got set';
ok $ENV{OPENSSL_BITS},         "OPENSSL_BITS=$ENV{OPENSSL_BITS}";
ok $ENV{OPENSSL_COUNTRY},      "OPENSSL_COUNTRY=$ENV{OPENSSL_COUNTRY}";
ok $ENV{OPENSSL_DAYS},         "OPENSSL_DAYS=$ENV{OPENSSL_DAYS}";
ok $ENV{OPENSSL_ORGANIZATION}, "OPENSSL_ORGANIZATION=$ENV{OPENSSL_ORGANIZATION}";
ok $ENV{OPENSSL_STATE},        "OPENSSL_STATE=$ENV{OPENSSL_STATE}";

note 'generate with defaults';
generate_cert_p({
  cert  => $tmpdir->child('irc-freenode.cert'),
  key   => $tmpdir->child('irc-freenode.key'),
  email => 'superman@convos.chat',
})->then(sub {
  is_deeply(
    $_[0],
    {
      bits         => $ENV{OPENSSL_BITS},
      cert         => $tmpdir->child('irc-freenode.cert'),
      common_name  => 'superman',
      country      => $ENV{OPENSSL_COUNTRY},
      days         => 3650,
      email        => 'superman@convos.chat',
      key          => $tmpdir->child('irc-freenode.key'),
      organization => $ENV{OPENSSL_ORGANIZATION},
      state        => $ENV{OPENSSL_STATE},
    },
    'cert info'
  );
})->wait;
test_cert(
  'irc-freenode',
  {
    bits         => $ENV{OPENSSL_BITS},
    common_name  => 'superman',
    country      => $ENV{OPENSSL_COUNTRY},
    email        => 'superman@convos.chat',
    organization => $ENV{OPENSSL_ORGANIZATION},
    state        => $ENV{OPENSSL_STATE},
  }
);

note 'generate with custom env';
$ENV{OPENSSL_BITS}         = 3072;
$ENV{OPENSSL_COUNTRY}      = 'NO';
$ENV{OPENSSL_DAYS}         = 365;
$ENV{OPENSSL_ORGANIZATION} = 'Cool Beans';
$ENV{OPENSSL_STATE}        = 'Oslo';
generate_cert_p({
  cert  => $tmpdir->child('irc-env.cert'),
  key   => $tmpdir->child('irc-env.key'),
  email => 'supergirl@convos.chat',
})->wait;
test_cert(
  'irc-env',
  {
    bits         => 3072,
    common_name  => 'supergirl',
    country      => 'NO',
    email        => 'supergirl@convos.chat',
    organization => 'Cool Beans',
    state        => 'Oslo',
  }
);

done_testing;

sub test_cert {
  my ($name, $exp) = @_;
  ok -s $tmpdir->child("$name.cert"), "$name.cert generated";
  ok -s $tmpdir->child("$name.key"),  "$name.key generated";

  my %cert;
  open my $OPENSSL, '-|',
    $ENV{OPENSSL_BIN} => qw(x509 -text -noout -in) => $tmpdir->child("$name.cert")
    or die "Read $name: $!";
  while (<$OPENSSL>) {
    $cert{bits}         = $1 if /(\d+)\s*bit/;
    $cert{common_name}  = $1 if /\bCN\s*=\s*([^,]+)/;
    $cert{country}      = $1 if /\bC\s*=\s*([^,]+)/;
    $cert{email}        = $1 if /\bemailAddress\s*=\s*([^,]+)/;
    $cert{organization} = $1 if /\bO\s*=\s*([^,]+)/;
    $cert{state}        = $1 if /\bST\s*=\s*([^,]+)/;
  }

  chomp $cert{$_} for keys %cert;

  is_deeply(
    \%cert,
    {
      bits         => $exp->{bits},
      common_name  => $exp->{common_name},
      country      => $exp->{country},
      email        => $exp->{email},
      organization => $exp->{organization},
      state        => $exp->{state},
    },
    "$name.cert content",
  );
}
