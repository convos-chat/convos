use t::Helper;

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [
    zadd => 'user:doe:conversations',
    time, 'magnet:00:23convos', time - 1, 'magnet:00batman', time - 2, 'bitlbee:00:26bitlbee'
  ],
  [sadd => 'user:doe:connections', 'magnet', 'bitlbee'],
  [hmset => 'user:doe:connection:magnet',  nick => 'doe'],
  [hmset => 'user:doe:connection:bitlbee', nick => 'doe'],
);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})
  ->header_like('Location', qr{/magnet/%23convos$}, 'Redirect to conversation');

$t->get_ok($t->tx->res->headers->location)->status_is(200);

$t->get_ok('/invalid/foo')->status_is(302)
  ->header_like('Location', qr{/magnet/%23convos$}, 'Redirect on invalid conversation');

$t->get_ok($t->tx->res->headers->location)->status_is(200)->element_exists_not('body.without-sidebar')
  ->element_exists('body.with-sidebar');

$t->get_ok('/bitlbee/&bitlbee')->status_is(200)->element_exists_not('body.without-sidebar')
  ->element_exists('body.with-sidebar');

$t->get_ok('/magnet/batman')->status_is(200)->element_exists('body.without-sidebar')
  ->element_exists_not('body.with-sidebar')->element_exists('head script')->element_exists('nav')
  ->element_exists('.notifications.container')->element_exists('.add-conversation.container')
  ->element_exists('.goto-bottom');

$t->get_ok('/magnet/batman?_pjax=some.element')->status_is(200)->element_exists('body.without-sidebar')
  ->element_exists_not('body.with-sidebar')->element_exists_not('head script')->element_exists_not('nav')
  ->element_exists_not('.notifications.container')->element_exists_not('.add-conversation.container')
  ->element_exists_not('.goto-bottom');

$t->get_ok('/')->header_like('Location', qr{/magnet/batman$}, 'Redirect on last conversation');

$t->get_ok('/chat/command-history')->status_is(200)->content_is('[]');

$t->get_ok('/chat/conversations')->status_is(200)->element_exists('ul.conversations')
  ->element_exists('li:nth-of-type(1) a[href="/convos"][data-unread="0"]')
  ->element_exists('li:nth-of-type(2) a[href="/magnet/batman"][data-unread="0"]')
  ->element_exists('li:nth-of-type(3) a[href="/magnet/%23convos"][data-unread="0"]')
  ->element_exists('li:nth-of-type(4) a[href="/bitlbee/&bitlbee"][data-unread="0"]')
  ->element_exists_not('li:nth-of-type(5)');

$t->get_ok('/chat/notifications')->status_is(200)->element_exists('ul.notifications')
  ->element_exists_not('li:nth-of-type(1)');

$t->get_ok('/chat/notifications', {Accept => 'application/json'})->status_is(200)->content_type_is('application/json');

$t->post_ok('/chat/notifications/clear')->status_is(200)->json_is('/cleared', 0);

done_testing;
