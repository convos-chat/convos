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
$ws->message_ok->json_message_is('/event', 'sent');
$ws->message_ok->json_message_is('/event', 'message');

my $url = $ws->message->[1] =~ /(http:[^"\s]+)/ ? $1 : $ws->message->[1];
$url =~ s!\\/!/!g;
$th->get_ok($url)->status_is(200)->text_like('h1', qr{^Paste created 20\d+-\d+-\d+T})
  ->text_is('pre', "1\n2\n3\n4");

my $id = $url =~ m!/(\d+)$! ? $1 : 'x';
ok -s $ws->app->core->home->child('superman@example.com', 'upload', $id), "paste $id saved on disk";

$th->get_ok("/api/embed?url=$url")->status_is(200)->text_is('pre', "1\n2\n3\n4");

#local $TODO = 'Need failing test';
#  ->json_message_is('/errors/0/message', 'Unable to handle "multiline_message".');

$url =~ s!(\d)$!{$1 + 1}!e;
$th->get_ok($url)->status_is(404);

done_testing;
