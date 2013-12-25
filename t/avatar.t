BEGIN {
  unless($ENV{REAL_AVATARS}) {
    $ENV{DEFAULT_AVATAR_URL} = '/image/avatar/convos.jpg';
    $ENV{GRAVATAR_AVATAR_URL} = '/image/avatar/convos.jpg';
  }
}
use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $dom = Mojo::DOM->new;
my $core = $t->app->core;
my($connection, $bytes, $cb);

*Convos::Core::Connection::connect = sub {
  diag 'Skip connecting to irc server';
};

*Mojo::IRC::write = sub {
  $bytes = $_[1];
  Mojo::IOLoop->timer(0.01, $cb);
};

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '', avatar => 'some_default_id' ],
  [ zadd => 'user:doe:conversations', time, 'convos:2epl:00:23convos', time - 1, 'convos:2epl:00batman' ],
  [ sadd => 'connections', 'doe:irc.perl.org' ],
  [ sadd => 'user:doe:connections', 'irc.perl.org' ],
  [ hmset => 'user:doe:connection:irc.perl.org', nick => 'doe' ],
);

{
  unlink '/tmp/convos/loopback-doe.jpg';
  $t->get_ok('/doe/avatar.jpg')->status_is(200)->header_is('Content-Type', 'image/jpeg');
  $t->get_ok('/invalid/avatar.jpg')->content_is("Could not find avatar.\n")->status_is(404);
}

{
  $t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);
  $t->get_ok('/convos/irc.perl.org/avatar.jpg')->status_is(200)->header_is('Content-Type', 'image/jpeg');
}

{
  $cb = sub {
    $connection = $core->_connection(login => 'doe', server => 'irc.perl.org');
    $connection->irc_rpl_whoisuser({
      params => [
        "whatever",
        "batman",
        "jhthorsen",
        "some.domain.com",
        "whatever",
        $t->ua->server->url->path('/jhthorsen/avatar.jpg')->to_string,
      ],
    });
  };

  $core->start;
  unlink '/tmp/convos/irc.perl.org-batman.jpg';
  $t->get_ok('/irc.perl.org/batman/avatar.jpg')->status_is(200)->header_is('Content-Type', 'image/jpeg');
  is $bytes, 'WHOIS batman', "write($bytes)";
}

{
  $t->websocket_ok('/socket');
  $connection->add_message({
    params => [ '#mojo', 'doe: see this &amp; link: http://convos.by?a=1&b=2#yikes # really cool' ],
    prefix => 'fooman!user@host',
  });
  $dom->parse($t->message_ok->message->[1]);
  ok $dom->at('li.message[data-server="irc.perl.org"][data-target="#mojo"][data-sender="fooman"]'), 'Got correct 6+#mojo';
  ok $dom->at('img[alt="fooman"][src="/irc.perl.org/fooman/avatar.jpg"]'), 'gravatar image based on user+host';
}

$t->finish_ok;

done_testing;
