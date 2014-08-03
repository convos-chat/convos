BEGIN {
  unless ($ENV{REAL_AVATARS}) {
    $ENV{DEFAULT_AVATAR_URL}  = '/re/mote/avatar/%s';
    $ENV{GRAVATAR_AVATAR_URL} = '/re/mote/avatar/%s';
  }
}
use t::Helper;
use File::Spec ();
use Mojo::JSON;
use Mojo::DOM;

plan skip_all => '/tmp/convos is required' unless -d '/tmp' and -w '/tmp';

my %gif = map { $_ => Mojo::Util::slurp($t->app->home->rel_file("public/image/avatar-$_.gif")) } 404, 500;
my ($host, $port) = map { $t->ua->server->url->$_ } qw( host port );

$t->app->routes->get(
  '/re/mote/avatar/a0196c429a4c02c1cc96afed12a0ed0c' => sub { shift->render(text => 'marcus avatar'); });
$t->app->routes->get(
  '/re/mote/avatar/d14559a471313305325c24e5f6bf08a1' => sub { shift->render(text => 'remote avatar'); });
$t->app->routes->get(
  '/re/mote/avatar/6f854cba5fd519bf70765b1d681355d4' => sub { shift->render(text => 'avatar by discover'); });

redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', 'nick' => 'doe', avatar => 'jhthorsen'],
);

{
  diag 'not logged in';
  $t->get_ok('/avatar?user=jhthorsen&host=convos.by')->status_is(200)->header_is('Content-Type', 'image/gif')
    ->content_is($gif{500}, 'Cannot discover avatar unless logged in');
}

{
  diag 'loopback avatar';
  redis_do([hset => 'convos:host2convos', '1.2.3.4' => 'loopback']);
  $t->get_ok('/avatar?user=~marcus&host=1.2.3.4')->status_is(200)
    ->content_is('marcus avatar', 'avatar from remote address')->header_like('Last-Modified', qr{\d});
  $t->get_ok('/avatar?user=marcus&host=1.2.3.4', {'If-Modified-Since' => Mojo::Date->new(time - 500)})->status_is(304)
    ->header_like('Last-Modified', qr{\d});
}

{
  diag 'login...';
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
  $t->get_ok('/')->status_is(302)->header_is(Location => '/magnet/%23convos');
}

{
  diag 'remote avatar from ' . $t->tx->req->url->to_string;
  redis_do([hset => 'convos:host2convos', 'example.com' => $t->tx->req->url->to_string]);
  $t->get_ok('/avatar?user=some_user&host=example.com')->status_is(200)
    ->content_is('remote avatar', 'avatar from remote address')->header_like('Last-Modified', qr{\d});
  $t->get_ok('/avatar?user=~some_user&host=example.com', {'If-Modified-Since' => Mojo::Date->new(time - 500)})
    ->status_is(304)->header_like('Last-Modified', qr{\d});
}

{
  local $TODO = 'Convos::User::_avatar_discover()';
  diag 'discover remote avatar';
  $t->get_ok('/avatar?nick=batman&user=~jhthorsen&host=irc.example.com')->status_is(200)
    ->content_is('avatar by discover', 'avatar from remote convos')->header_like('Last-Modified', qr{\d});
}

done_testing;
