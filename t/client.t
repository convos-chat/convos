use t::Helper;

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [
    zadd => 'user:doe:conversations',
    time, 'magnet:00:23convos', time - 1, 'magnet:00batman', time - 2, 'bitlbee:00:26bitlbee', time - 3,
    'bitlbee:00:23convos'
  ],
  [sadd => 'user:doe:connections', 'magnet', 'bitlbee'],
  [hmset => 'user:doe:connection:magnet',  nick => 'doe'],
  [hmset => 'user:doe:connection:bitlbee', nick => 'doe'],
);

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})
  ->header_is('Location', '/magnet/%23convos', 'Redirect to conversation');

$t->get_ok($t->tx->res->headers->location)->status_is(200);
is $t->tx->res->dom->find('nav a.active')->contents->size, 1, 'only one active element';

$t->get_ok('/invalid/foo')->status_is(404);

$t->get_ok('/bitlbee/&bitlbee')->status_is(200);

$t->get_ok('/magnet/batman')->status_is(200)->element_exists('head script')->element_exists('nav')
  ->element_exists('.notification-list.sidebar-right');

$t->get_ok('/magnet/batman?_pjax=some.element')->status_is(200)->element_exists_not('head script')
  ->element_exists('nav')->element_exists_not('.notifications.container');

$t->get_ok('/')->header_is('Location', '/magnet/batman', 'Redirect on last conversation');

$t->get_ok('/chat/command-history')->status_is(200)->content_is('[]');

$t->get_ok('/chat/notifications')->status_is(200)->element_exists('ul[data-notifications]')
  ->text_is('ul h3', 'No notifications');

$t->get_ok('/chat/notifications', {Accept => 'application/json'})->status_is(200)->content_type_is('application/json');

$t->post_ok('/chat/notifications/clear')->status_is(200)->json_is('/cleared', 0);

done_testing;
