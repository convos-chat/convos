use Test::More;
use Convos::Util qw(disk_usage generate_secret is_true);
use Convos::Util qw(pretty_connection_name require_module short_checksum);
use Mojo::JSON qw(false true);
use Mojo::Loader qw(data_section);
use Mojo::Util qw(b64_encode gzip sha1_sum);

subtest disk_usage => sub {
SKIP: {
    skip $@, 1 unless my $stats = eval { disk_usage '/' };
    is_deeply [sort keys %$stats],
      [
      qw(block_size blocks_free blocks_total blocks_used dev inodes_free inodes_total inodes_used)],
      'disk_usage';
    ok $stats->{block_size} > 1,                        'block_size';
    ok $stats->{blocks_total} >= $stats->{blocks_used}, 'blocks_total/used';
    ok $stats->{blocks_total} >= $stats->{blocks_free}, 'blocks_total/free';
    ok $stats->{inodes_total} >= $stats->{inodes_used}, 'inodes_total/used';
    ok $stats->{inodes_total} >= $stats->{inodes_free}, 'inodes_total/free';
  }
};

subtest generate_secret => sub {
  is length(generate_secret), 40, 'generate_secret';
  my %secrets;
  map { $secrets{+Convos::Util::_generate_secret_urandom()}++ } 1 .. 1000 if -r '/dev/urandom';
  map { $secrets{+Convos::Util::_generate_secret_fallback()}++ } 1 .. 1000;
  is_deeply [values %secrets], [map {1} values %secrets],
    '1..1000 is not nearly enough to prove anything, but testing it anyways';
};

subtest 'is_true' => sub {
  ok !is_true($_), "is not true: $_" for qw(0 Off No false), false;
  ok is_true($_),  "is true: $_"     for qw(1 On Yes true),  true;

  my @warn;
  local $ENV{CONVOS_SYSLOG} = 'foo';
  local $SIG{__WARN__}      = sub { push @warn, $_[0] };
  ok !is_true('ENV:CONVOS_SYSLOG'), 'foo fallbacks to false';
  like "@warn", qr{Value should be.* "foo"}, 'foo is not boolean';
};

subtest pretty_connection_name => sub {
  is pretty_connection_name('irc://tyldum%40Convos%2Flibera:passw0rd@example.com:7000/'), 'libera',
    'ZNC style userinfo';

  is pretty_connection_name('irc://user:passw0rd@example.com:7000/'), 'example', 'normal userinfo';
  is pretty_connection_name('irc://example.com:7000/'),               'example', 'no userinfo';
  is pretty_connection_name('irc://ssl.irc.perl.org/'),               'magnet',  'no userinfo';
  is pretty_connection_name('ircs://irc.oftc.net:6697'),              'oftc',    'oftc';
  is pretty_connection_name('irc.oftc.net'),             'oftc',        'oftc without scheme';
  is pretty_connection_name('irc.darkscience.net:6697'), 'darkscience', 'darkscience';
};

subtest require_module => sub {
  eval { require_module 'Foo::Bar' };
  my $err = $@;
  like $err, qr{You need to install Foo::Bar to use main:}, 'require_module failed message';
  like $err, qr{\./script/convos cpanm -n Foo::Bar},        'require_module failed cpanm';

  eval { require_module 'Convos::Util' };
  ok !$@, 'require_module success';
};

subtest short_checksum => sub {
  is short_checksum(sha1_sum(3)),          'd952uzY7q7tY7bH4', 'short_checksum sha1_sum';
  is short_checksum('jhthorsen@cpan.org'), 'gNQ981Q2TztxSsRL', 'short_checksum email';
  is short_checksum(sha1_sum('jhthorsen@cpan.org')), 'gNQ981Q2TztxSsRL',
    'short_checksum sha1_sum email';
};

done_testing;
