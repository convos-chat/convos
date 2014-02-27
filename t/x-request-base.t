use t::Helper;

$t->get_ok('/')->status_is(302)->header_like(Location => qr{:\d+/register$});
$t->get_ok('/', {'X-Request-Base' => 'http://convos.by/app'})->status_is(302)
  ->header_is(Location => 'http://convos.by/app/register');

done_testing;
