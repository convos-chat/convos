use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

delete $ENV{CONVOS_REDIS_URL};    # make sure it's not set from outside

my @tests = (
  {like => 'CONVOS_REDIS_URL is not set'},
  {env  => {MOJO_MODE => 'production'}, url => 'redis://127.0.0.1:6379/1',},
  {
    env => {DOTCLOUD_DATA_REDIS_URL => 'redis://redis:s3cret1@bd0715e0.dotcloud.com:7474'},
    url => 'redis://redis:s3cret1@bd0715e0.dotcloud.com:7474',
  },
  {
    env => {REDISTOGO_URL => 'redis://redistogo:s3cret2@drum.redistogo.com:9092/'},
    url => 'redis://redistogo:s3cret2@drum.redistogo.com:9092/',
  },
  {
    env => {REDISCLOUD_URL => 'redis://rediscloud:s3cret3@rediscloud.com:12345/'},
    url => 'redis://rediscloud:s3cret3@rediscloud.com:12345/',
  },
  {
    env => {REDISTOGO_URL => 'redis://redistogo:s3cret4@drum.redistogo.com:9092/', CONVOS_REDIS_INDEX => 12},
    url => 'redis://redistogo:s3cret4@drum.redistogo.com:9092/12',
  },
  {env => {CONVOS_REDIS_URL => 'redis://localhost/3', CONVOS_REDIS_INDEX => 12}, url => 'redis://localhost/3'},
);

for my $test (@tests) {
  local %ENV = %ENV;
  my $like = $test->{like};
  $ENV{$_} = $test->{env}{$_} for keys %{$test->{env}};

  is eval { Test::Mojo->new('Convos')->app->redis->server }, $test->{url}, $test->{url} // 'undefined url';
  like $@, qr{$like}, $like if $like;
}

done_testing;
