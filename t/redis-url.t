use Test::More;
use Convos::Plugin::Helpers;

my @tests = (
  {like => 'CONVOS_REDIS_URL is not set',},
  {
    env => {DOTCLOUD_DATA_REDIS_URL => 'redis://redis:lshYSDfQDe@bd0715e0.dotcloud.com:7474',},
    url => 'redis://redis:lshYSDfQDe@bd0715e0.dotcloud.com:7474',
  },
  {
    env => {REDISTOGO_URL => 'redis://redistogo:44ec0bc04dd4a5afe77a649acee7a8f3@drum.redistogo.com:9092/',},
    url => 'redis://redistogo:44ec0bc04dd4a5afe77a649acee7a8f3@drum.redistogo.com:9092/',
  },
  {
    env => {
      REDISTOGO_URL      => 'redis://redistogo:44ec0bc04dd4a5afe77a649acee7a8f3@drum.redistogo.com:9092/',
      CONVOS_REDIS_INDEX => 12,
    },
    url => 'redis://redistogo:44ec0bc04dd4a5afe77a649acee7a8f3@drum.redistogo.com:9092/12',
  },
  {env => {CONVOS_REDIS_URL => 'redis://localhost/3', CONVOS_REDIS_INDEX => 12,}, url => 'redis://localhost/3',},
);

for my $test (@tests) {
  my $like = $test->{like};

  local $ENV{CONVOS_REDIS_URL};
  local $ENV{REDISTOGO_URL};
  local $ENV{DOTCLOUD_DATA_REDIS_URL};
  local $ENV{CONVOS_REDIS_INDEX};

  $ENV{$_} = $test->{env}{$_} for keys %{$test->{env}};

  is eval { Convos::Plugin::Helpers::REDIS_URL() }, $test->{url}, $test->{url} // 'undefined url';
  like $@, qr{$like}, $like if $like;
}

done_testing;
