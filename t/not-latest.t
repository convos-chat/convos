use Test::Mojo;
use Test::More;

my ($exit, $version);
*Convos::exit = sub { $exit++; };
no warnings 'redefine';
require Convos;

*Mojo::Redis::get = sub {
  my ($redis, $key, $cb) = @_;
  diag "get $key => $version";
  $redis->$cb($version);
  Mojo::IOLoop->stop;
};

{
  my $c = Convos->new;
  $exit    = undef;
  $version = 0;
  Mojo::IOLoop->start;
  is $exit, 1, 'exit() because of old version';
}

{
  my $c = Convos->new;
  $exit    = undef;
  $version = 1_000;
  Mojo::IOLoop->start;
  is $exit, undef, 'latest version';
}

done_testing;
