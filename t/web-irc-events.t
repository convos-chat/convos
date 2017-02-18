use lib '.';
use t::Helper;
use Test::Mojo::IRC;

my $th   = t::Helper->t;
my $ws   = t::Helper->t($th->app);
my $irc  = Test::Mojo::IRC->start_server;
my $user = $th->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

$ws->websocket_ok('/events')
  ->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

for my $t ($th, $ws) {
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
}

$ws->websocket_ok('/events');

# Note: tls=0 is to avoid reconnecting to the test irc server
$th->post_ok('/api/connections',
  json => {name => 'test', url => sprintf('irc://%s?tls=0', $irc->server)})->status_is(200);
my $c = $th->app->core->get_user('superman@example.com')->get_connection('irc-test');

note 'connected';
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_like('/message', qr{Connected to})->json_message_is('/state', 'connected')
  ->json_message_is('/type', 'connection');

# irc welcome messages
note 'welcome';
$ws->message_ok->message_like(qr{Looking}i,  'Looking up your hostname');
$ws->message_ok->message_like(qr{Checking},  'Checking Ident');
$ws->message_ok->message_like(qr{Found},     'Found your hostname');
$ws->message_ok->message_like(qr{No Ident}i, 'No ident');

$irc->run(
  [qr{JOIN}, ['join-convos.irc']],
  sub {
    # TODO: not ok 23 - send message
    note 'join';
    $ws->send_ok({json => {method => 'send', message => '/join #Convos', connection_id => $c->id}});
    $ws->message_ok->json_message_is('/connection_id', $c->id)
      ->json_message_is('/connection_id', 'irc-test')->json_message_is('/dialog_id', '#convos')
      ->json_message_is('/event', 'state')->json_message_is('/frozen', '')
      ->json_message_is('/is_private', 0)->json_message_is('/name', '#Convos')
      ->json_message_is('/topic', '')->json_message_has('/ts')->json_message_is('/type', 'frozen');
    $ws->message_ok->json_message_has('/id')->json_message_is('/connection_id', 'irc-test')
      ->json_message_is('/event', 'sent')->json_message_is('/message', '/join #Convos')
      ->json_message_is('/dialog_id', '#convos');

    is $c->get_dialog('#convos')->password, '', 'password is not undef';
  }
);

note 'msg';
$ws->send_ok(
  {json => {method => 'send', message => '/msg supergirl too cool', connection_id => $c->id}});
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/dialog_id', 'supergirl')->json_message_is('/event', 'message')
  ->json_message_is('/from',    'superman')->json_message_is('/highlight', false)
  ->json_message_is('/message', 'too cool')->json_message_is('/name',      'supergirl')
  ->json_message_is('/type',    'private')->json_message_has('/ts');
$ws->message_ok->json_message_is('/event', 'sent');

note 'nick';
$irc->run(
  [qr{NICK}, ['nick.irc']],
  sub {
    $ws->send_ok(
      {json => {method => 'send', message => '/nick supergirl', connection_id => $c->id}});
    $ws->message_ok->json_message_has('/id')->json_message_is('/message', '/nick supergirl');
    $ws->message_ok->json_message_is('/event', 'state')
      ->json_message_is('/connection_id', 'irc-test')->json_message_is('/nick', 'supergirl')
      ->json_message_has('/ts')->json_message_is('/type', 'me');
  }
);

note 'get topic invalid';
$irc->run(
  [qr{TOPIC}, ['topic-get.irc']],
  sub {
    $ws->send_ok({json => {method => 'send', message => '/topic', connection_id => $c->id}});
    $ws->message_ok->json_message_like('/errors/0/message', qr{without channel name});
  }
);

note 'get topic';
$irc->run(
  [qr{TOPIC}, ['topic-get.irc']],
  sub {
    $ws->send_ok(
      {
        json =>
          {method => 'send', message => '/topic', connection_id => $c->id, dialog_id => '#convos'}
      }
    );
    $ws->message_ok->json_message_has('/id')->json_message_is('/connection_id', 'irc-test')
      ->json_message_is('/message', '/topic')->json_message_is('/topic', 'Some cool topic');
  }
);

note 'http://www.mirc.com/colors.html';
$c->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batman!super.girl@i.love.debian.org',
    params => [
      'superduper',
      "\x0313swagger2\x0f/\x0306master\x0f \x0314f70340b\x0f \x0315Jan Henning Thorsen\x0f: Released version 0.85..."
    ]
  }
);
$ws->message_ok->json_message_is('/message',
  'swagger2/master f70340b Jan Henning Thorsen: Released version 0.85...');

note 'part event';
$c->_event_part({params => ['#convos', 'Bye'], prefix => 'batman!super.girl@i.love.debian.org'});
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/message', 'Bye')
  ->json_message_is('/nick', 'batman')->json_message_is('/type', 'part');

note 'quit event';
$c->_event_quit({params => ['So long!'], prefix => 'batman!super.girl@i.love.debian.org'});
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/dialog_id', undef)->json_message_is('/nick', 'batman')
  ->json_message_is('/message', 'So long!')->json_message_is('/type', 'quit');

note 'part command';
$irc->run(
  [qr{PART}, ['part.irc']],
  sub {
    $ws->send_ok({json => {method => 'send', message => '/part #convos', connection_id => $c->id}});
    $ws->message_ok->json_message_has('/id')->json_message_is('/connection_id', 'irc-test')
      ->json_message_is('/message', '/part #convos');
  }
);

{
  local $TODO = 'How can we tell that something is an unknown command now?';
  $ws->send_ok(
    {
      json =>
        {method => 'send', message => '/nope', connection_id => $c->id, dialog_id => '#convos'}
    }
  );
  $ws->message_ok->json_message_is('/errors/0/message', 'Unknown IRC command.');
}

note 'disconnect command';
$ws->send_ok({json => {method => 'send', message => '/disconnect', connection_id => $c->id}});
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/state', 'disconnected')->json_message_is('/type', 'connection')
  ->json_message_like('/message', qr{have quit});
$ws->message_ok->json_message_like('/dialog_id', qr{super})
  ->json_message_is('/frozen', 'Not connected.');
$ws->message_ok->json_message_like('/dialog_id', qr{super})
  ->json_message_is('/frozen', 'Not connected.');
$ws->message_ok->json_message_has('/id')->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/message', '/disconnect');

# Test to make sure we don't leak events.
# The get_ok() is just a hack to make sure the server has
# emitted the "finish" event.
ok $user->core->backend->has_subscribers('user:superman@example.com'), 'subscribed';
$ws->finish_ok;
$ws->get_ok('/')->status_is(200);
ok !$user->core->backend->has_subscribers('user:superman@example.com'), 'unsubscribed';

done_testing;

__DATA__
@@ join-convos.irc
:superman!superman@i.love.debian.org JOIN :#Convos
:hybrid8.debian.local 332 superman #Convos :some cool topic
:hybrid8.debian.local 333 superman #Convos jhthorsen!jhthorsen@i.love.debian.org 1432932059
:hybrid8.debian.local 353 superman = #convos :Superman20001 @batman
:hybrid8.debian.local 366 superman #Convos :End of /NAMES list.
@@ nick.irc
:superman!test15044@i.love.debian.org NICK :supergirl
@@ topic-get.irc
:hybrid8.debian.local 332 supergirl #convos :Some cool topic
@@ topic-set.irc
:supergirl!test20949@i.love.debian.org TOPIC #convos :awesomeness
@@ part.irc
:supergirl!~test96908@0::1 PART #convos
