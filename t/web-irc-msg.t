use lib '.';
use t::Helper;
use Test::Mojo::IRC;

my $th   = t::Helper->t;
my $ws   = t::Helper->t($th->app);
my $irc  = Test::Mojo::IRC->start_server;
my $user = $th->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

for my $t ($th, $ws) {
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
}

$ws->websocket_ok('/events');

# Note: tls=0 is to avoid reconnecting to the test irc server
$th->post_ok('/api/connections',
  json => {name => 'test', url => sprintf('irc://%s?tls=0', $irc->server)})->status_is(200);
my $c = $th->app->core->get_user('superman@example.com')->get_connection('irc-test');

# flush connect messages
while ($ws->message_ok) {
  last if $ws->message->[1] =~ /No Ident response/;
}

note 'simple message';
$ws->send_ok(
  {json => {method => 'send', message => '/msg supergirl too cool', connection_id => $c->id}});
$ws->message_ok->json_message_is('/event',         'sent');
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/dialog_id', 'supergirl')->json_message_is('/event', 'message')
  ->json_message_is('/from',    'superman')->json_message_is('/highlight', false)
  ->json_message_is('/message', 'too cool')->json_message_is('/name',      'supergirl')
  ->json_message_is('/type',    'private')->json_message_has('/ts');

note 'message with newline';
$ws->send_ok(
  {json => {method => 'send', message => "/msg supergirl with\nnewline", connection_id => $c->id}});
$ws->message_ok->json_message_is('/event',         'sent');
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/event', 'message')->json_message_is('/message', 'with', '/message with');
$ws->message_ok->json_message_is('/connection_id', 'irc-test')
  ->json_message_is('/event', 'message')
  ->json_message_is('/message', 'newline', '/message newline');

note 'message too many newlines';
$ws->send_ok(
  {json => {method => 'send', message => "/msg supergirl 1\n2\n3\n4", connection_id => $c->id}});
$ws->message_ok->json_message_is('/event', 'sent')
  ->json_message_is('/errors/0/message', 'Unable to handle "multiline_message".');

done_testing;
