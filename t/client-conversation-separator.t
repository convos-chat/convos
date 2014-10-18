BEGIN { $ENV{N_MESSAGES} = 4; }
use t::Helper;
use Mojo::Loader;
my $loader = Mojo::Loader->new;
my $time;

redis_do(
  [hmset => 'user:doe',                   digest => 'E2G3goEIb8gpw', email => ''],
  [hmset => 'user:doe:connection:magnet', nick   => 'doe',           state => 'disconnected'],
);

for (split /\n/, $loader->data(main => 'convos.log.ep')) {
  /"timestamp":([\d\.]+)/ or die "Invalid regexp for $_";
  $time = $1;
  redis_do zadd => "user:doe:connection:magnet:#convos:msg" => $time => $_;
}

$t->post_ok('/login', form => {login => 'doe', password => 'barbar'});

{
  my $last_read_time = 1392916952;
  redis_do zadd => 'user:doe:conversations', $last_read_time, 'magnet:00:23convos';
  $t->get_ok('/magnet/%23convos')->status_is(200)->element_exists(qq(ul[data-last-read-time="$last_read_time"]))
    ->element_exists('#a11ed1af-c8a2-f0ee-c420-12b4cdd14a42.history-starting-point');
}

{    # on scroll back with two many new messages
  my $last_read_time = 1392744006;
  redis_do zadd => 'user:doe:conversations', $last_read_time, 'magnet:00:23convos';
  $t->get_ok('/magnet/%23convos')->status_is(200)->element_exists(qq(ul[data-last-read-time="$last_read_time"]))
    ->element_exists_not('.history-starting-point');

  my $to = $t->tx->res->dom->at(qq(ul[data-last-read-time="$last_read_time"]))->{'data-start-time'};
  $t->get_ok("/magnet/%23convos?last-read-time=$last_read_time&to=$to")->status_is(200)
    ->element_exists(qq(ul[data-last-read-time="$last_read_time"]))->element_exists('.history-starting-point');
}

done_testing;

__DATA__
@@ convos.log.ep
{"uuid":"28fa49597103a5ec05cd605f9074998e","target":"#convos","highlight":0,"message":"yeah. i think we need a default.","network":"magnet","nick":"doe","timestamp":1392462168.12178,"host":"ti0034a400-2938.bb.online.no","user":"~doe","event":"message"}
{"timestamp":1392744006.97908,"highlight":1,"uuid":"54a8992c25ea63c6d09274330e6d9433","user":"~doe","nick":"doe","host":"ti0034a400-2938.bb.online.no","message":"hey doe ","event":"message","network":"magnet","target":"#convos"}
{"host":"localhost","network":"magnet","event":"message","target":"#convos","message":"does this work?","timestamp":1392744040.85341,"highlight":0,"uuid":"65e5dfe1-08e9-c0ce-9c69-426893cda9e9","nick":"doe","user":"doe"}
{"network":"magnet","timestamp":1392754563.9967,"target":"#convos","event":"message","highlight":0,"host":"ti0034a400-2938.bb.online.no","user":"~doe","message":"too tired today. will try to figure out the avatar part another day","nick":"doe","uuid":"70a73b3769a155c66d0b34e75b570cb7"}
{"network":"magnet","host":"localhost","event":"message","uuid":"a11ed1af-c8a2-f0ee-c420-12b4cdd14a42","message":"hey","highlight":0,"timestamp":1392916952.65855,"user":"doe","nick":"doe","target":"#convos"}
{"target":"#convos","nick":"doe","user":"doe","timestamp":1392916966.68917,"highlight":0,"message":"test123","host":"localhost","event":"message","uuid":"34265234-9bf2-dd75-a422-868183ac3200","network":"magnet"}
