#!perl
use lib '.';
use t::Helper;

my $th   = t::Helper->t;
my $user = $th->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p;

my $ws = t::Helper->t($th->app);
$ws->websocket_ok('/events')
  ->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')->finish_ok;

for my $t ($th, $ws) {
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
}

$ws->websocket_ok('/events');
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $irc_server = t::Helper->irc_server_connect($connection);

note 'connect';
$ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_like('/message', qr{Connected to})->json_message_is('/state', 'connected');
$ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_like('/message', qr{Looking up your hostname});
$ws->message_ok->json_message_is('/connection_id', 'irc-localhost') for 1 .. 3;

note 'debug';
$ws->send_ok({json => {method => 'debug', what => 'ever'}})
  ->message_ok->json_message_is('/event', 'debug');

note 'ping';
$ws->send_ok({json => {method => 'ping'}})->message_ok->json_message_is('/event', 'pong')
  ->json_message_like('/ts', qr{^\d+});

note 'send_p';
my %send = (method => 'send');
$ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
  ->json_message_is('/event', 'sent')->json_message_is('/errors/0/message', ('Invalid input.') x 2);

$send{connection_id} = 'irc-whatever';
$send{message}       = '/kick superduper';
$ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
  ->json_message_is('/event', 'sent')
  ->json_message_is('/errors/0/message', ('Connection not found.') x 2);

$send{connection_id} = 'irc-localhost';
$ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
  ->json_message_is('/event', 'sent')
  ->json_message_is('/errors/0/message', ('Cannot send without target.') x 2);

$irc_server->once(
  message => sub {
    shift->emit(write => ":superman!sm\@localhost KICK #convos superduper :So long...\r\n");
  }
);
$send{dialog_id} = '#convos';
$send{id}        = '42';
$ws->send_ok({json => \%send})->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/event', 'state')
  ->json_message_is('/kicker', 'superman')->json_message_is('/message', 'So long...')
  ->json_message_is('/nick', 'superduper')->json_message_is('/type', 'part')
  ->json_message_like('/ts', qr{^\d+-\d+-\d+});

$ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/dialog_id', '#convos')->json_message_is('/event', 'sent')
  ->json_message_is('/id', '42')->json_message_is('/message', '/kick superduper')
  ->json_message_is('/method', 'send');

done_testing;
