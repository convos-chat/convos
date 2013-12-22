use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ zadd => 'user:doe:conversations', time, 'irc:2eperl:2eorg:00:23convos', time - 1, 'irc:2eperl:2eorg:00batman' ],
  [ sadd => 'user:doe:connections', 'irc.perl.org' ],
  [ hmset => 'user:doe:connection:irc.perl.org', nick => 'doe' ],
);

$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })
  ->header_like('Location', qr{/irc.perl.org/%23convos$}, 'Redirect to conversation');

$t->get_ok($t->tx->res->headers->location)
  ->status_is(200);

$t->get_ok('/inv.alid/foo')
  ->header_like('Location', qr{/irc.perl.org/%23convos$}, 'Redirect on invalid conversation');

$t->get_ok($t->tx->res->headers->location)
  ->status_is(200)
  ->element_exists_not('body.without-nick-list')
  ->element_exists('body.with-nick-list')
  ;

$t->get_ok('/irc.perl.org/batman')
  ->status_is(200)
  ->element_exists('body.without-nick-list')
  ->element_exists_not('body.wit-nick-list')
  ;

$t->get_ok('/')->header_like('Location', qr{/irc.perl.org/batman$}, 'Redirect on last conversation');

$t->get_ok('/command-history')
  ->status_is(200)
  ->content_is('[]')
  ;

$t->get_ok('/conversations')
  ->status_is(200)
  ->element_exists('ul.conversations')
  ->element_exists('li:nth-of-type(1)')
  ->element_exists('a[href="/irc.perl.org/batman"][data-unread="0"]')
  ->element_exists('li:nth-of-type(2)')
  ->element_exists('a[href="/irc.perl.org/%23convos"][data-unread="0"]')
  ->element_exists_not('li:nth-of-type(3)')
  ;

$t->get_ok('/notifications')
  ->status_is(200)
  ->element_exists('ul.notifications')
  ->element_exists_not('li:nth-of-type(1)')
  ;

$t->get_ok('/notifications',{Accept => 'application/json'})
  ->status_is(200)
  ->content_type_is('application/json')
  ;


$t->post_ok('/notifications/clear')
  ->status_is(200)
  ->json_is('/cleared', 0)
  ;

done_testing;
