use Test::Mojo;
use Test::More;

my ($exit, $version);
*Convos::exit = sub { $exit++; };
no warnings 'redefine';
require Convos;

Mojo::Util::monkey_patch(
  'Convos::Upgrader',
  steps => sub {
    return $_[0]->{steps} unless @_ == 2;
    $_[0]->{steps} = $_[1];
    Mojo::IOLoop->stop;
  }
);

Mojo::Util::monkey_patch(
  'Mojo::Redis',
  get => sub {
    my ($redis, $key, $cb) = @_;
    diag "get $key => $version";
    $redis->$cb($version);
  }
);

Mojo::Util::monkey_patch(
  'Mojo::Redis',
  scard => sub {
    my ($redis, $key, $cb) = @_;
    diag "scard $key => 1";
    $redis->$cb(1);
  }
);

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
