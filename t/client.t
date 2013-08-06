use t::Helper;

redis_do(
  [ set => 'user:doe:uid', 42 ],
  [ hmset => 'user:42', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:42:conversations', time, '6:00:23wirc', time - 1, '6:00batman' ],
  [ sadd => 'user:42:connections', 6 ],
  [ hmset => 'connection:6', nick => 'doe' ],
);

$t->post_ok('/', form => { login => 'doe', password => 'barbar' })->header_like('Location', qr{/6/%23wirc$}, 'Redirect to conversation');
$t->get_ok($t->tx->res->headers->location)->status_is(200);
$t->get_ok('/2/foo')->header_like('Location', qr{/6/%23wirc$}, 'Redirect on invalid conversation');

$t->get_ok($t->tx->res->headers->location)
  ->status_is(200)
  ->element_exists_not('body.without-nick-list')
  ->element_exists('body.with-nick-list')
  ;

$t->get_ok('/6/batman')
  ->status_is(200)
  ->element_exists('body.without-nick-list')
  ->element_exists_not('body.wit-nick-list')
  ;

$t->get_ok('/')->header_like('Location', qr{/6/batman$}, 'Redirect on last conversation');

$t->get_ok('/command-history')
  ->status_is(200)
  ->content_is('[]')
  ;

$t->get_ok('/conversations')
  ->status_is(200)
  ->element_exists('ul.conversations')
  ->element_exists('li:nth-of-type(1)')
  ->element_exists('a[href="/6/batman"][data-unread="0"]')
  ->element_exists('li:nth-of-type(2)')
  ->element_exists('a[href="/6/%23wirc"][data-unread="0"]')
  ->element_exists_not('li:nth-of-type(3)')
  ;

$t->get_ok('/notifications')
  ->status_is(200)
  ->element_exists('ul.notifications')
  ->element_exists_not('li:nth-of-type(1)')
  ;

$t->post_ok('/notifications/clear')
  ->status_is(200)
  ->json_is('/cleared', 0)
  ;

done_testing;
