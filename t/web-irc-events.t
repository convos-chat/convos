#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;

my $server = t::Server::Irc->new->start;
my $th     = t::Helper->t;
my $user   = $th->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p;

my $ws = t::Helper->t($th->app);
$ws->websocket_ok('/events')
  ->message_ok->json_message_is('/errors/0/message', 'Need to log in first.')
  ->json_message_is('/event', 'handshake')->finish_ok;

for my $t ($th, $ws) {
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
}

$ws->websocket_ok('/events');
my $connection = $user->connection({url => 'irc://localhost'});
$server->client($connection)->server_event_ok('_irc_event_nick')->process_ok;

subtest connect => sub {
  $ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
    ->json_message_like('/message', qr{Connected to})->json_message_is('/state', 'connected');
  $ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
    ->json_message_like('/message', qr{Looking up your hostname});
  $ws->message_ok->json_message_is('/connection_id', 'irc-localhost') for 1 .. 3;
};

subtest debug => sub {
  $ws->send_ok({json => {method => 'debug', what => 'ever'}})
    ->message_ok->json_message_is('/event', 'debug');
};

subtest ping => sub {
  $ws->send_ok({json => {method => 'ping'}})->message_ok->json_message_is('/event', 'pong')
    ->json_message_like('/ts', qr{^\d+});
};

my %send;
subtest 'send_p - invalid input' => sub {
  %send = (method => 'send');
  $ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
    ->json_message_is('/event', 'sent')
    ->json_message_is('/errors/0/message', ('Invalid input.') x 2);
};

subtest 'send_p - no connection' => sub {
  $send{connection_id} = 'irc-whatever';
  $send{message}       = '/kick superduper';
  $ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
    ->json_message_is('/event', 'sent')
    ->json_message_is('/errors/0/message', ('Connection not found.') x 2);
};

subtest 'send_p - no target' => sub {
  $send{connection_id} = 'irc-localhost';
  $ws->send_ok({json => \%send})->message_ok->json_message_like('/id', qr{^\d+})
    ->json_message_is('/event', 'sent')
    ->json_message_is('/errors/0/message', ('Cannot send without target.') x 2);
};

subtest 'send_p - kick' => sub {
  $send{conversation_id} = '#convos';
  $send{id}              = '42';
  $ws->send_ok({json => \%send});
  $server->server_write_ok(":superman!sm\@localhost KICK #convos superduper :So long...\r\n");
  $ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
    ->json_message_is('/conversation_id', '#convos')->json_message_is('/event', 'state')
    ->json_message_is('/kicker',          'superman')->json_message_is('/message', 'So long...')
    ->json_message_is('/nick',            'superduper')->json_message_is('/type', 'part')
    ->json_message_like('/ts', qr{^\d+-\d+-\d+});
};

subtest 'send_p - response' => sub {
  $ws->message_ok->json_message_is('/connection_id', 'irc-localhost')
    ->json_message_is('/conversation_id', '#convos')->json_message_is('/event', 'sent')
    ->json_message_is('/id',              '42')->json_message_is('/message', '/kick superduper')
    ->json_message_is('/method',          'send');
};

done_testing;
