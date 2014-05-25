BEGIN {
  $ENV{CONVOS_SECURE_COOKIES} = 1;
}
use t::Helper;

redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''], [del => 'user:doe:connections'],);

{
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302)
    ->header_like('Set-Cookie', qr{\bsecure\b}i);
}

done_testing;
