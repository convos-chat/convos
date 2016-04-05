use t::Helper;
use Mojo::IRC;

no warnings 'redefine';
*Mojo::IRC::connect = sub { pop->($_[0], '') };

my $t = t::Helper->t;
$t->websocket_ok('/events/bi-directional');
$t->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->websocket_ok('/events/bi-directional');

# update profile
$t->send_ok(
  {json => {id => 42, op => 'updateUser', params => {body => {password => 'supersecret'}}}});
$t->message_ok->json_message_is('/id', 42)->json_message_is('/body/email', 'superman@example.com');

$t->send_ok(
  {json => {id => 43, op => 'createConnection', params => {body => {url => "irc://localhost"}}}});
$t->message_ok->json_message_is('/id', 43)->json_message_is('/body/id', 'irc-localhost')
  ->json_message_is('/body/state', 'queued');
$t->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/state', 'connected');

my $irc = $t->app->core->get_user('superman@example.com')->get_connection('irc-localhost');
$irc->dialog({name => '#convos'});

# join
$irc->_event_irc_join({params => ['#convos'], prefix => 'Supergirl!super.girl@i.love.debian.org'});
$t->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/event', 'dialog')
  ->json_message_is('/nick', 'Supergirl')->json_message_is('/type', 'join');

# part
$irc->_event_irc_part(
  {params => ['#convos', 'Zzz'], prefix => 'Supergirl!super.girl@i.love.debian.org'});
$t->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/event', 'dialog')
  ->json_message_is('/message', 'Zzz')->json_message_is('/nick', 'Supergirl')
  ->json_message_is('/type', 'part');

# quit
$irc->_event_irc_part(
  {params => ['#convos', 'Bye'], prefix => 'Supergirl!super.girl@i.love.debian.org'});
$t->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/event', 'dialog')
  ->json_message_is('/message', 'Bye')->json_message_is('/nick', 'Supergirl')
  ->json_message_is('/type', 'part');

#die $t->message->[1];

# Test to make sure we don't leak events.
# The get_ok() is just a hack to make sure the server has
# emitted the "finish" event.
ok $user->core->backend->has_subscribers('user:superman@example.com'), 'subscribed';
$t->finish_ok;
$t->get_ok('/')->status_is(200);
ok !$user->core->backend->has_subscribers('user:superman@example.com'), 'unsubscribed';

done_testing;
