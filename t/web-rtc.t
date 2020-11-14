#!perl
use lib '.';
use t::Helper;

plan skip_all => 'TEST_IRC_SERVER=localhost:6667' unless $ENV{TEST_IRC_SERVER};

my $t_jane = t::Helper->t;
my $t_joe  = t::Helper->t($t_jane->app);
my %nicks;

$t_jane->{nick} = "t_jane_$$";
$t_joe->{nick}  = "t_joe_$$";

note 'setup';
setup($_)                                                    for $t_jane, $t_joe;
wait_for_message_ok($_, qr{"conversation_id":".ct_web_rtc"}) for $t_jane, $t_joe;

note 'input check';
my $offer = Mojo::Loader::data_section(qw(main sdp-offer-original.data));
my %msg   = (
  connection_id   => 'irc-localhost',
  conversation_id => '#ct_web_rtc',
  event           => 'signal',
  target          => $t_joe->{nick},
  offer           => $offer,
);
$t_jane->send_ok({json => {method => 'rtc', %msg}});
wait_for_message_ok($t_jane, qr{"event":"rtc"});

for my $key (qw(target conversation_id event connection_id)) {
  delete $msg{$key};
  my $msg
    = $key eq 'conversation_id' ? 'Conversation not found.'
    : $key eq 'connection_id'   ? 'Connection not found.'
    :                             'Missing property.';

  $t_jane->send_ok({json => {method => 'rtc', %msg}});
  wait_for_message_ok($t_jane, qr{"errors"})->json_message_is('/errors/0/message', $msg, $msg);
}

note 'jane signal joe';
wait_for_message_ok($t_joe, qr{"event":"rtc"})->json_message_is('/connection_id', 'irc-localhost')
  ->json_message_is('/conversation_id', '#ct_web_rtc')->json_message_is('/from', $t_jane->{nick})
  ->json_message_is('/event',           'rtc')
  ->json_message_is('/offer',           nl(Mojo::Loader::data_section(qw(main sdp-from-irc.data))))
  ->json_message_is('/type',            'signal');

note 'robin joins';
my $t_robin = t::Helper->t($t_jane->app);
$t_robin->{nick} = "t_robin_$$";
setup($t_robin);
wait_for_message_ok($t_robin, qr{"conversation_id":".ct_web_rtc"});

%msg = (connection_id => 'irc-localhost', conversation_id => '#ct_web_rtc', event => 'call');
$t_robin->send_ok({json => {method => 'rtc', %msg}});
wait_for_message_ok($t_robin, qr{"event":"rtc"});

$msg{event} = 'hangup';
$t_robin->send_ok({json => {method => 'rtc', %msg}});
wait_for_message_ok($t_robin, qr{"event":"rtc"});

note 'robin signal jane and joe';
for my $t ($t_jane, $t_joe) {
  wait_for_message_ok($t, qr{"type":"call"})->json_message_is('/connection_id', 'irc-localhost')
    ->json_message_is('/conversation_id', '#ct_web_rtc')
    ->json_message_is('/from',            $t_robin->{nick})->json_message_is('/event', 'rtc')
    ->json_message_is('/type',            'call');
  wait_for_message_ok($t, qr{"type":"hangup"})->json_message_is('/from', $t_robin->{nick})
    ->json_message_is('/type', 'hangup');
}

done_testing;

sub nl {
  local $_ = shift;
  s!\r?\n!\r\n!g;
  return $_;
}

sub setup {
  my $t    = shift;
  my $user = $t->app->core->user({email => "$t->{nick}\@example.com"})->set_password('s3cret');
  $user->save_p->$wait_success('save_p');

  $t->post_ok('/api/user/login', json => {email => "$t->{nick}\@example.com", password => 's3cret'})
    ->status_is(200);

  my $connection = $user->connection(
    {name => 'localhost', protocol => 'irc', url => "irc://$ENV{TEST_IRC_SERVER}?tls=0"});
  $connection->conversation({name => '#ct_web_rtc', frozen => ''});
  $connection->connect;

  $t->websocket_ok('/events');
}

sub wait_for_message_ok {
  my ($t, $re) = @_;

  my $desc = join ' ', $t->{nick}, 'wait for', $re;
  subtest $desc => sub {
    while (1) {
      $t->message_ok("wait for $re");
      last unless $t->success;
      last if $t->message->[1] =~ $re;
    }
  };

  return $t;
}

__DATA__
@@ sdp-offer-original.data
v=0
o=mozilla...THIS_IS_SDPARTA-76.0.1 9134645872599048060 0 IN IP4 0.0.0.0
s=-
t=0 0
a=fingerprint:sha-256 95:6E:6F:E2:0B:FF:78:EC:F8:B2:90:37:EC:87:3B:55:99:2F:8C:4C:73:5E:39:7E:60:80:72:BA:31:15:9F:CC
a=group:BUNDLE 0 1
a=ice-options:trickle
a=msid-semantic:WMS *
m=audio 9 UDP/TLS/RTP/SAVPF 109 9 0 8 101
c=IN IP4 0.0.0.0
a=sendrecv
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2/recvonly urn:ietf:params:rtp-hdrext:csrc-audio-level
a=extmap:3 urn:ietf:params:rtp-hdrext:sdes:mid
a=fmtp:109 maxplaybackrate=48000;stereo=1;useinbandfec=1
a=fmtp:101 0-15
a=ice-pwd:914fe83c43228d1802ee427e43d88daf
a=ice-ufrag:1b22377f
a=mid:0
a=msid:{da44f045-e682-664b-a9dd-5ae62ed18bfb} {c2c4c46e-06ba-f341-b189-d0e558d50e29}
a=rtcp-mux
a=rtpmap:109 opus/48000/2
a=rtpmap:9 G722/8000/1
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000/1
a=setup:actpass
a=ssrc:252769094 cname:{a1933fc7-ba84-fe42-80c6-536c60bd34e0}
m=video 9 UDP/TLS/RTP/SAVPF 120 121 126 97
c=IN IP4 0.0.0.0
a=sendrecv
a=extmap:3 urn:ietf:params:rtp-hdrext:sdes:mid
a=extmap:4 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:5 urn:ietf:params:rtp-hdrext:toffset
a=extmap:6/recvonly http://www.webrtc.org/experiments/rtp-hdrext/playout-delay
a=fmtp:126 profile-level-id=42e01f;level-asymmetry-allowed=1;packetization-mode=1
a=fmtp:97 profile-level-id=42e01f;level-asymmetry-allowed=1
a=fmtp:120 max-fs=12288;max-fr=60
a=fmtp:121 max-fs=12288;max-fr=60
a=ice-pwd:914fe83c43228d1802ee427e43d88daf
a=ice-ufrag:1b22377f
a=mid:1
a=msid:{da44f045-e682-664b-a9dd-5ae62ed18bfb} {6788765b-5bc9-834a-a87b-7e5618b25a8d}
a=rtcp-fb:120 nack
a=rtcp-fb:120 nack pli
a=rtcp-fb:120 ccm fir
a=rtcp-fb:120 goog-remb
a=rtcp-fb:121 nack
a=rtcp-fb:121 nack pli
a=rtcp-fb:121 ccm fir
a=rtcp-fb:121 goog-remb
a=rtcp-fb:126 nack
a=rtcp-fb:126 nack pli
a=rtcp-fb:126 ccm fir
a=rtcp-fb:126 goog-remb
a=rtcp-fb:97 nack
a=rtcp-fb:97 nack pli
a=rtcp-fb:97 ccm fir
a=rtcp-fb:97 goog-remb
a=rtcp-mux
a=rtpmap:120 VP8/90000
a=rtpmap:121 VP9/90000
a=rtpmap:126 H264/90000
a=rtpmap:97 H264/90000
a=setup:actpass
@@ sdp-from-irc.data
v=0
o=mozilla...THIS_IS_SDPARTA-76.0.1 9134645872599048060 0 IN IP4 0.0.0.0
s=-
t=0 0
a=fingerprint:sha-256 95:6E:6F:E2:0B:FF:78:EC:F8:B2:90:37:EC:87:3B:55:99:2F:8C:4C:73:5E:39:7E:60:80:72:BA:31:15:9F:CC
a=group:BUNDLE 0 1
a=ice-options:trickle
a=msid-semantic:WMS *
m=audio 9 UDP/TLS/RTP/SAVPF 109 9 0 8 101
c=IN IP4 0.0.0.0
a=sendrecv
a=ice-pwd:914fe83c43228d1802ee427e43d88daf
a=ice-ufrag:1b22377f
a=mid:0
a=msid:{da44f045-e682-664b-a9dd-5ae62ed18bfb} {c2c4c46e-06ba-f341-b189-d0e558d50e29}
a=rtcp-mux
a=rtpmap:109 opus/48000/2
a=rtpmap:9 G722/8000/1
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000/1
a=setup:actpass
a=ssrc:252769094 cname:{a1933fc7-ba84-fe42-80c6-536c60bd34e0}
m=video 9 UDP/TLS/RTP/SAVPF 120 121 126 97
c=IN IP4 0.0.0.0
a=sendrecv
a=ice-pwd:914fe83c43228d1802ee427e43d88daf
a=ice-ufrag:1b22377f
a=mid:1
a=msid:{da44f045-e682-664b-a9dd-5ae62ed18bfb} {6788765b-5bc9-834a-a87b-7e5618b25a8d}
a=rtcp-mux
a=rtpmap:120 VP8/90000
a=rtpmap:121 VP9/90000
a=rtpmap:126 H264/90000
a=rtpmap:97 H264/90000
a=setup:actpass
