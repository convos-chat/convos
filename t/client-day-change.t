BEGIN {
  $ENV{TZ}         = 'EDT';
  $ENV{N_MESSAGES} = 4;
  $ENV{TEST_TIME}  = 1409443199.9;    # Sun Aug 31 00:59:59.8 2014
  require Convos::Controller::Chat;
  no warnings qw/prototype/;
  *Convos::Controller::Chat::time = sub { $ENV{TEST_TIME} };
}

use t::Helper;
use Mojo::Loader;
my $loader = Mojo::Loader->new;
my $time;

redis_do(
  [hmset => 'user:doe',                   digest => 'E2G3goEIb8gpw', email => ''],
  [hmset => 'user:doe:connection:magnet', nick   => 'doe',           state => 'disconnected'],
  [zadd => 'user:doe:conversations', 1, 'magnet:00:23convos'],
);

for (split /\n/, $loader->data(main => 'convos.log.ep')) {
  /"timestamp":([\d\.]+)/ or die "Invalid regexp for $_";
  $time = $1;
  redis_do zadd => "user:doe:connection:magnet:#convos:msg" => $time => $_;
}

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
$t->post_ok("/profile/timezone/offset?hour=@{[(localtime)[2]]}");

# ws day_changed
$t->websocket_ok('/socket')->message_ok->message_like(qr{id="day-changed-1409443200});

# html day_changed inside messages
$t->get_ok('/magnet/%23convos?from=1409435997.12178')->status_is(200)
  ->element_exists('.messages li:nth-of-type(1)[id="28fa49597103a5ec05cd605f9074998e"]')
  ->element_exists('.messages li:nth-of-type(2)[id="day-changed-1409443200.99998"]')
  ->element_exists('.messages li:nth-of-type(3)[id="54a8992c25ea63c6d09274330e6d9433"]')
  ->element_exists('.messages li:nth-of-type(4)[id="65e5dfe1-08e9-c0ce-9c69-426893cda9e9"]')
  ->element_exists('.day-changed')->text_like('.messages li:nth-of-type(2) .content', qr{Day changed to 31});

# html day_changed at end of messages
$t->get_ok('/magnet/%23convos?to=1409443200.00001')->status_is(200)->element_exists('.day-changed')
  ->text_like('.messages li:nth-of-type(2) .content', qr{Day changed to 31});

# html day_changed not in messages
$t->get_ok('/magnet/%23convos?from=1409443201')->status_is(200)->element_exists_not('.day-changed');

done_testing;

__DATA__
@@ convos.log.ep
{"uuid":"28fa49597103a5ec05cd605f9074998e","target":"#convos","highlight":0,"message":"YESTERDAY","network":"magnet","nick":"doe","timestamp":1409443197.12178,"host":"ti0034a400-2938.bb.online.no","user":"~doe","event":"message"}
{"timestamp":1409443200.99998,"highlight":1,"uuid":"54a8992c25ea63c6d09274330e6d9433","user":"~doe","nick":"doe","host":"ti0034a400-2938.bb.online.no","message":"DAY CHANGE","event":"message","network":"magnet","target":"#convos"}
{"host":"localhost","network":"magnet","event":"message","target":"#convos","message":"AAAA","timestamp":1409443201.12178,"highlight":0,"uuid":"65e5dfe1-08e9-c0ce-9c69-426893cda9e9","nick":"doe","user":"doe"}
{"network":"magnet","timestamp":1409443207.1017,"target":"#convos","event":"message","highlight":0,"host":"ti0034a400-2938.bb.online.no","user":"~doe","message":"BBBB","nick":"doe","uuid":"70a73b3769a155c66d0b34e75b570cb7"}
{"network":"magnet","host":"localhost","event":"message","uuid":"a11ed1af-c8a2-f0ee-c420-12b4cdd14a42","message":"CCCC","highlight":0,"timestamp":1409443217,"user":"doe","nick":"doe","target":"#convos"}
{"target":"#convos","nick":"doe","user":"doe","timestamp":1409443224,"highlight":0,"message":"DDDD","host":"localhost","event":"message","uuid":"34265234-9bf2-dd75-a422-868183ac3200","network":"magnet"}
