#!perl
use lib '.';
use t::Helper;
use Mojo::IOLoop;
use Convos::Core;

$ENV{CONVOS_CONNECT_DELAY} = 0.2;
my $core = Convos::Core->new(backend => 'Convos::Core::Backend');
$core->start;

my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
t::Helper->irc_server_connect($connection);

my @rtc_events;
$connection->on(rtc => sub { shift; push @rtc_events, [@_] });

note 'call #convos';
my %msg = (connection_id => 'irc-localhost', dialog_id => '#convos', event => 'call');
my ($err, $res, $sent);
$connection->rtc_p({%msg})->$wait_reject('Dialog not found.');
$connection->dialog({name => '#convos'});
$connection->rtc_p({%msg})->$wait_reject('Not yet connected.');
t::Helper->irc_server_messages(qr{NICK} => ['welcome.irc']);
t::Helper->irc_server->once(message => sub { $sent = pop });
$res = $connection->rtc_p({%msg})->$wait_success('call #convos');
is_deeply $res, {}, 'called #convos';
is $sent, "NOTICE #convos :\x01RTCZ CALL\x01", 'rtcz';

note 'hangup superwoman';
@msg{qw(dialog_id event)} = qw(superwoman hangup);
$connection->rtc_p({%msg})->$wait_reject('Dialog not found.');
$connection->dialog({name => 'superwoman'});
t::Helper->irc_server_messages(qr{ISON} => ['ison.irc']);
t::Helper->irc_server->once(message => sub { $sent = pop });
$res = $connection->rtc_p({%msg})->$wait_success('call superwoman');
is_deeply $res, {}, 'called superwoman';
is $sent, "NOTICE superwoman :\x01RTCZ HANGUP\x01", 'rtcz';

note 'signalling #convos';
@msg{qw(dialog_id event ice)} = ('#convos', 'signal', "0\r\n-\r\n" x 200);
$connection->rtc_p({%msg})->$wait_reject('Missing property: target.');
$msg{target} = 'superwoman';
t::Helper->irc_server->once(message => sub { $sent = pop });
$connection->rtc_p({%msg})->$wait_success('event ice #convos');
like $sent, qr{NOTICE superwoman :\x01RTCZ ICE 0/0 \#convos \S+==\x01}, 'rtcz ice #convos';

note 'signalling superwoman';
delete $msg{ice};
@msg{qw(dialog_id event answer)} = ('superwoman', 'signal', "0\r\n-\r\n" x 200);
$msg{target} = 'superwoman';
t::Helper->irc_server->once(message => sub { $sent = pop });
$connection->rtc_p({%msg})->$wait_success('event answer superwoman');
like $sent, qr{NOTICE superwoman :\x01RTCZ ANS 0/0 superwoman \S+==\x01}, 'rtcz answer superwoman';

note 'incoming call in #convos';
t::Helper->irc_server_messages(
  from_server => ":superwoman!sg\@example.com NOTICE #convos :\x01RTCZ CALL\x01\r\n",
  $connection, '_irc_event_ctcpreply_rtcz',
);
is_deeply(
  \@rtc_events,
  [[call => $connection->get_dialog('#convos'), {from => 'superwoman'}]],
  'got incoming call'
);

note 'hangup in superwoman';
@rtc_events = ();
t::Helper->irc_server_messages(
  from_server => ":superwoman!sg\@example.com NOTICE superman :\x01RTCZ HANGUP\x01\r\n",
  $connection, '_irc_event_ctcpreply_rtcz',
);
is_deeply(\@rtc_events, [[hangup => $connection->get_dialog('superwoman'), {from => 'superwoman'}]],
  'got hangup');

done_testing;
