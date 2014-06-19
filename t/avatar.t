BEGIN {
  unless ($ENV{REAL_AVATARS}) {
    $ENV{DEFAULT_AVATAR_URL}  = '/image/%s';
    $ENV{GRAVATAR_AVATAR_URL} = '/image/%s';
  }
}
use t::Helper;
use File::Spec ();
use Mojo::JSON;
use Mojo::DOM;

plan skip_all => '/tmp/convos is required' unless -d '/tmp' and -w '/tmp';

my %gif = map { $_ => Mojo::Util::slurp($t->app->home->rel_file("public/image/avatar-$_.gif")) } 404, 500;
my $fresh = $t->app->home->rel_file('/public/image/a0196c429a4c02c1cc96afed12a0ed0c');
my ($host, $port) = map { $t->ua->server->url->$_ } qw( host port );

unlink glob($fresh);
redis_do(
  [hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''],
  [zadd => 'user:doe:conversations', time, 'magnet:00:23convos', time - 1, 'magnet:00batman'],
  [sadd => 'user:doe:connections',   'magnet'],
  [hmset => 'user:doe:connection:magnet', 'nick' => 'doe', avatar => 'jhthorsen'],
);

{
  diag 'invalid request';
  $t->get_ok('/avatar?user=jhthorsen&host=convos.by')->status_is(200)->header_is('Content-Type', 'image/gif')
    ->content_is($gif{500}, 'Cannot discover avatar unless logged in');
  unlink glob('/tmp/convos/*');
}

{
  diag 'loopback avatar';
  redis_do([hset => 'convos:host2convos', '1.2.3.4' => 'loopback']);
  Mojo::Util::spurt('fresh', $fresh);
  $t->get_ok('/avatar?user=marcus&host=1.2.3.4')->status_is(200)->content_is('fresh', 'avatar from 3rd party');

  Mojo::Util::spurt('cached',
    File::Spec->catdir(File::Spec->tmpdir, 'convos/_image_a0196c429a4c02c1cc96afed12a0ed0c.jpg'));
  $t->get_ok('/avatar?user=marcus&host=1.2.3.4')->status_is(200)->content_is('cached', 'avatar from cache');
  unlink glob('/tmp/convos/*');
  unlink $fresh;
}

{
  diag 'login...';
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
  $t->get_ok('/')->status_is(302)->header_like(Location => qr{:\d+/magnet/%23convos});
}

{
  local $TODO = 'Need to run WHOIS and figure out the real identity';
  $t->get_ok('/avatar?user=jhthorsen&host=convos.by')->status_is(302)
    ->header_like(Location => qr{/image/deebdae9dacaf91b89f9cb8bed87993e$});
}

{
  diag 'custom loopback avatar';
  $fresh = $t->app->home->rel_file('/public/image/6f68bd7cac66e7333e083d94c96428e7');
  Mojo::Util::spurt('custom', $fresh);
  $t->get_ok('/avatar?user=doe&host=1.2.3.4')->status_is(200)->content_is('custom', 'custom loopback avatar');
  unlink $fresh;
}

{
  local $TODO = 'This test does not work, since it loops';
  diag 'remote avatar';
  redis_do([hset => 'convos:host2convos', '1.2.3.4' => " http : //$host : $port "]);
  $t->get_ok('/avatar?user=jhthorsen&host=1.2.3.4');
  unlink glob('/tmp/convos/*');
}

done_testing;
