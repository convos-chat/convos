use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],);

# not logged in
$t->get_ok('/oembed?url=http://google.com')->status_is(302)->header_is('Location', '/');

# login
$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);

$t->get_ok('/oembed?url=http://google.com')->status_is(204)->content_is('');

$t->get_ok('/oembed?url=http://catoverflow.com/cats/MG5CCEJ.gif')->status_is(200)
  ->element_exists('div.embed img[src="http://catoverflow.com/cats/MG5CCEJ.gif"]');

$t->get_ok('/oembed?url=http://www.youtube.com/watch?v=erltj70kVd0')->status_is(200)
  ->content_like(qr{<iframe.*/embed/erltj70kVd0});

done_testing;
