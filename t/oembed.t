use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],);

# not logged in
$t->get_ok('/oembed?url=http://google.com')->status_is(302)->header_like('Location', qr{/$});

# login
$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);

$t->get_ok('/oembed?url=http://google.com')->status_is(204);

$t->get_ok('/oembed?url=http://catoverflow.com/cats/MG5CCEJ.gif')->status_is(200)
  ->element_exists('div.embed img[src="http://catoverflow.com/cats/MG5CCEJ.gif"]');

$t->get_ok('/oembed?url=http://www.youtube.com/watch?v=erltj70kVd0')->status_is(200)
  ->element_exists('div.embed iframe[src^="//www.youtube-nocookie.com/embed/erltj70kVd0"]');

done_testing;
