#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;
use Mojo::IOLoop;
use Convos::Core;

$ENV{CONVOS_CONNECT_DELAY} = 0.2;
my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new(backend => 'Convos::Core::Backend');
$core->start;

my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});

my @rtc_events;
$connection->on(rtc => sub { shift; push @rtc_events, [@_] });

note 'call #convos';
my %msg = (connection_id => 'irc-localhost', conversation_id => '#convos', event => 'call');
my ($err, $res, $msg);
$connection->rtc_p({%msg})->$wait_reject('Conversation not found.');

$connection->conversation({name => '#convos'});
$connection->rtc_p({%msg})->$wait_reject('Not connected.');

$server->client($connection)->server_event_ok('_irc_event_nick')->server_write_ok(['welcome.irc'])
  ->process_ok;
$server->server_event_ok('_irc_event_ctcpreply_rtcz', sub { $msg = pop });
$res = $connection->rtc_p({%msg})->$wait_success('call #convos');
$server->process_ok;
is_deeply $res, {}, 'called #convos';
is $msg->{raw_line}, "NOTICE #convos :\x01RTCZ CALL\x01", 'rtcz';

note 'hangup superwoman';
@msg{qw(conversation_id event)} = qw(superwoman hangup);
$connection->rtc_p({%msg})->$wait_reject('Conversation not found.');
$connection->conversation({name => 'superwoman'});
$server->server_event_ok('_irc_event_ctcpreply_rtcz', sub { $msg = pop });
$res = $connection->rtc_p({%msg})->$wait_success('call superwoman');
is_deeply $res, {}, 'called superwoman';
$server->process_ok;
is $msg->{raw_line}, "NOTICE superwoman :\x01RTCZ HANGUP\x01", 'rtcz';

note 'signalling #convos';
@msg{qw(conversation_id event ice)} = ('#convos', 'signal', "0\r\n-\r\n" x 200);
$connection->rtc_p({%msg})->$wait_reject('Missing property: target.');
$msg{target} = 'superwoman';
$server->server_event_ok('_irc_event_ctcpreply_rtcz', sub { $msg = pop });
$connection->rtc_p({%msg})->$wait_success('event ice #convos');
$server->process_ok;
like $msg->{raw_line}, qr{NOTICE superwoman :\x01RTCZ ICE 0/0 \#convos \S+==\x01},
  'rtcz ice #convos';

note 'signalling superwoman';
delete $msg{ice};
@msg{qw(conversation_id event answer)} = ('superwoman', 'signal', "0\r\n-\r\n" x 200);
$msg{target} = 'superwoman';
$server->server_event_ok('_irc_event_ctcpreply_rtcz', sub { $msg = pop });
$connection->rtc_p({%msg})->$wait_success('event answer superwoman');
$server->process_ok;
like $msg->{raw_line}, qr{NOTICE superwoman :\x01RTCZ ANS 0/0 superwoman \S+==\x01},
  'rtcz answer superwoman';

note 'incoming call in #convos';
$server->server_write_ok(":superwoman!sg\@example.com NOTICE #convos :\x01RTCZ CALL\x01\r\n")
  ->client_event_ok('_irc_event_ctcpreply_rtcz')->process_ok;
is_deeply(
  \@rtc_events,
  [[call => $connection->get_conversation('#convos'), {from => 'superwoman'}]],
  'got incoming call'
);

note 'incoming signalling superwoman';
@rtc_events = ();
$server->server_write_ok(
  ":superwoman!sg\@example.com NOTICE superman :\x01RTCZ ICE 0/0 superman H4sIADvpyV4AA8tMTrU1UDVwUTVw1IVQo7xR3ihvlDfKG+WN8kZ5o7xR3vDiAQBX4L2X9AoAAA==\x01\r\n"
)->client_event_ok('_irc_event_ctcpreply_rtcz')->process_ok;
is_deeply(
  \@rtc_events,
  [[
    signal => $connection->get_conversation('superwoman'),
    {from => 'superwoman', ice => "0\r\n-\r\n" x 200}
  ]],
  'got incoming signal'
);

note 'hangup in superwoman';
@rtc_events = ();
$server->server_write_ok(":superwoman!sg\@example.com NOTICE superman :\x01RTCZ HANGUP\x01\r\n")
  ->client_event_ok('_irc_event_ctcpreply_rtcz')->process_ok;
is_deeply(\@rtc_events,
  [[hangup => $connection->get_conversation('superwoman'), {from => 'superwoman'}]],
  'got hangup');

done_testing;
