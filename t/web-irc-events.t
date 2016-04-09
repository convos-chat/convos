use t::Helper;
use Test::Mojo::IRC;

my $t      = t::Helper->t;
my $irc    = Test::Mojo::IRC->start_server;
my $msg_id = 40;
my $user   = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200)->websocket_ok('/events/bi-directional');

# create + connect
# Note: tls=0 is to avoid reconnecting to the test irc server
send_ok(createConnection => {name => 'test', url => sprintf('irc://%s?tls=0', $irc->server)});
$t->message_ok->json_message_is('/code', 200)->json_message_is('/id', id())
  ->json_message_is('/body/id', 'irc-test')->json_message_is('/body/state', 'queued');
$t->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_like('/message', qr{Connected to})->json_message_is('/state', 'connected')
  ->json_message_is('/type', 'connection');

# irc welcome messages
$t->message_ok->message_like(qr{Looking}i,  'Looking up your hostname');
$t->message_ok->message_like(qr{Checking},  'Checking Ident');
$t->message_ok->message_like(qr{Found},     'Found your hostname');
$t->message_ok->message_like(qr{No Ident}i, 'No Ident response');

my $c = $t->app->core->get_user('superman@example.com')->get_connection('irc-test');

$irc->run(
  [qr{JOIN}, ['join-convos.irc']],
  sub {
    send_ok(commandFromUser => {command => '/join #Convos', connection_id => $c->id});
    $t->message_ok->json_message_is('/code', 200)
      ->json_message_is('/body/connection_id', 'irc-test')->json_message_is('/body/id', '#convos')
      ->json_message_is('/body/name', '#Convos')->json_message_is('/body/is_private', 0)
      ->json_message_is('/body/topic', '')->json_message_is('/body/frozen', '');
  }
);

$irc->run(
  [qr{NICK}, ['nick.irc']],
  sub {
    send_ok(commandFromUser => {command => '/nick supergirl', connection_id => $c->id});
    $t->message_ok->json_message_is('/event', 'state')
      ->json_message_is('/connection_id', 'irc-test')->json_message_is('/nick', 'supergirl')
      ->json_message_is('/type', 'me');
    $t->message_ok->json_message_is('/code', 200)
      ->json_message_is('/body/command', '/nick supergirl');
  }
);

$irc->run(
  [qr{TOPIC}, ['topic-get.irc']],
  sub {
    send_ok(commandFromUser => {command => '/topic', connection_id => $c->id});
    $t->message_ok->json_message_is('/code', 500)->json_message_has('/body/errors/0/message');
  }
);

$irc->run(
  [qr{TOPIC}, ['topic-get.irc']],
  sub {
    send_ok(
      commandFromUser => {command => '/topic', connection_id => $c->id, dialog_id => '#convos'});
    $t->message_ok->json_message_is('/code', 200)->json_message_is('/body/command', '/topic')
      ->json_message_is('/body/topic', 'Some cool topic');
  }
);

$c->_event_irc_part(
  {params => ['#convos', 'Bye'], prefix => 'batman!super.girl@i.love.debian.org'});
$t->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/message', 'Bye')
  ->json_message_is('/nick', 'batman')->json_message_is('/type', 'part');

$c->_event_irc_quit(
  {params => ['#convos', 'So long!'], prefix => 'batman!super.girl@i.love.debian.org'});
$t->message_ok->json_message_is('/connection_id', 'irc-test')->json_message_is('/dialog_id', undef)
  ->json_message_is('/nick', 'batman')->json_message_is('/message', 'So long!')
  ->json_message_is('/type', 'part');

$irc->run(
  [qr{PART}, ['part.irc']],
  sub {
    send_ok(commandFromUser => {command => '/part #convos', connection_id => $c->id});
    $t->message_ok->json_message_is('/code', 200)
      ->json_message_is('/body/command', '/part #convos');
  }
);

send_ok(commandFromUser => {command => '/nope', connection_id => $c->id, dialog_id => '#convos'});
$t->message_ok->json_message_is('/code', 500)
  ->json_message_is('/body/errors/0/message', 'Unknown IRC command.');

send_ok(commandFromUser => {command => '/disconnect', connection_id => $c->id});
$t->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/state', 'disconnected')->json_message_is('/type', 'connection')
  ->json_message_like('/message', qr{have quit});
$t->message_ok->json_message_is('/body/command', '/disconnect')->json_message_is('/code', 200);

done_testing;

sub id { $msg_id += $_[0] || 0; }

sub send_ok {
  my ($op, $params) = @_;
  $t->send_ok({json => {id => id(1), op => $op, params => {body => $params}}}, $op);
}

__DATA__
@@ join-convos.irc
:Superman20001!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 superman #convos :some cool topic
:hybrid8.debian.local 333 superman #convos jhthorsen!jhthorsen@i.love.debian.org 1432932059
:hybrid8.debian.local 353 superman = #convos :Superman20001 @batman
:hybrid8.debian.local 366 superman #convos :End of /NAMES list.
@@ nick.irc
:superman!test15044@i.love.debian.org NICK :supergirl
@@ topic-get.irc
:hybrid8.debian.local 332 supergirl #convos :Some cool topic
:hybrid8.debian.local 333 supergirl #convos jhthorsen!jhthorsen@i.love.debian.org 1432932059
@@ topic-set.irc
:supergirl!test20949@i.love.debian.org TOPIC #convos :awesomeness
@@ part.irc
:supergirl!~test96908@0::1 PART #convos
