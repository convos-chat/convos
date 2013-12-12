use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ sadd => 'user:doe:connections', 'localhost:6667' ],
  [ hmset => 'user:doe:connection:localhost:6667', nick => 'doe', host => 'localhost:6667', channels => '#foo' ],
);

my $server = $t->app->redis->subscribe('convos:user:fooman:localhost:6667');
my($form, $tmp);

# login
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);

$t->get_ok('/settings')
  ->element_exists('form[action="/settings/connection"][method="post"]')
  ->element_exists('input[name="server"][id="server"][value="localhost:6667"]')
  ->element_exists('input[name="nick"][id="nick"][value="doe"]')
  ;

$form = {
  server => 'localhost:6667',
  nick => 'ice_cool',
  channels => '#foo',
};
$t->post_ok('/localhost:6667/settings/edit', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/settings$}, 'Redirect back to settings page')
  ;

done_testing;
