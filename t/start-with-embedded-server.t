use Mojo::Base -base;
use Test::More;
use Convos;

$ENV{CONVOS_REDIS_URL} = 'localhost:123456789';

{
  local $SIG{USR2} = sub { };                # emulate hypntoad (hackish)
  local $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  eval { Convos->new };
  like $@, qr{Cannot start embedded backend from hypnotoad}, 'cannot start CONVOS_BACKEND_EMBEDDED with hypntoad';
}

{
  my $start = 0;

  local $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  local *Convos::Core::start = sub { $start++; };
  Convos->new;
  is $start, 1, 'backend started';
}

done_testing;
