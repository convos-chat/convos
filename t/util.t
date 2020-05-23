use Test::More;
use Convos::Util qw(require_module sdp_decode sdp_encode short_checksum);
use Mojo::Loader 'data_section';
use Mojo::Util qw(b64_encode gzip md5_sum);

is short_checksum(md5_sum(3)), '7Mvfktc4v4MZ8q68', 'short_checksum md5_sum';
is short_checksum('jhthorsen@cpan.org'), 'gGgA67dutavZz2t6', 'short_checksum email';
is short_checksum(md5_sum('jhthorsen@cpan.org')), 'gGgA67dutavZz2t6',
  'short_checksum md5_sum email';

eval { require_module 'Foo::Bar' };
my $err = $@;
like $err, qr{You need to install Foo::Bar to use main:}, 'require_module failed message';
like $err, qr{\./script/convos cpanm -n Foo::Bar},        'require_module failed cpanm';

eval { require_module 'Convos::Util' };
ok !$@, 'require_module success';

for my $name (qw(answer.sdp offer.sdp)) {
  my $sdp     = data_section 'main', $name;
  my @sdp     = split /\r?\n/, $sdp;
  my $encoded = sdp_encode join "\r\n", @sdp;
  my @decoded = split /\r\n/, sdp_decode $encoded;
  my $n       = 0;

  @sdp = grep { !/^(?:a=ssrc|a=extmap:\d|a=fmtp:\d|a=rtcp-fb:\d)/ } @sdp;
  is shift(@decoded), shift(@sdp), "sdp rountrip (@{[++$n]}) $name" while @sdp;
  unlike $encoded, qr{\r\n}, "newlines in $name";

  my $sl = length $sdp;
  my $zl = length b64_encode gzip($encoded), '';
  ok $zl < $sl, "gzip $name $zl < $sl";
}

done_testing;

__DATA__
@@ answer.sdp
v=0
o=mozilla...THIS_IS_SDPARTA-76.0.1 6307873433363431743 0 IN IP4 0.0.0.0
s=-
t=0 0
a=fingerprint:sha-256 19:97:6D:29:DC:FB:AE:24:DB:9C:04:B9:CF:AA:E7:D4:A3:8C:77:89:2F:79:0C:7A:58:C4:83:9E:C8:A8:2A:1A
a=group:BUNDLE 0 1
a=ice-options:trickle
a=msid-semantic:WMS *
m=audio 9 UDP/TLS/RTP/SAVPF 111 9 0 8 126
c=IN IP4 0.0.0.0
a=sendrecv
a=fmtp:111 maxplaybackrate=48000;stereo=1;useinbandfec=1
a=fmtp:126 0-15
a=ice-pwd:83fbffaf4093d3b10cefca58312faff8
a=ice-ufrag:a38d67c4
a=mid:0
a=msid:{3828b2e3-a1b7-0941-860e-4a1fbda13c75} {af518c82-5fd6-a240-b390-f6063724dbee}
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=rtpmap:9 G722/8000/1
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:126 telephone-event/8000/1
a=setup:active
a=ssrc:3841967369 cname:{aba0d2fb-f1b2-014d-8415-11a2d658b7d0}
m=video 9 UDP/TLS/RTP/SAVPF 96 98
c=IN IP4 0.0.0.0
a=sendrecv
a=fmtp:96 max-fs=12288;max-fr=60
a=fmtp:98 max-fs=12288;max-fr=60
a=ice-pwd:83fbffaf4093d3b10cefca58312faff8
a=ice-ufrag:a38d67c4
a=mid:1
a=msid:{3828b2e3-a1b7-0941-860e-4a1fbda13c75} {fdd59892-dd57-6543-ab74-482d30dadce8}
a=rtcp-mux
a=rtpmap:96 VP8/90000
a=rtpmap:98 VP9/90000
a=setup:active
a=ssrc:1551183966 cname:{aba0d2fb-f1b2-014d-8415-11a2d658b7d0}
@@ offer.sdp
v=0
o=- 7633300665000791411 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=msid-semantic: WMS Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k
m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104 9 0 8 106 105 13 110 112 113 126
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:50VQ
a=ice-pwd:b6/176+swvZtv+ag5TuQ34mO
a=ice-options:trickle
a=fingerprint:sha-256 D1:C0:81:63:E2:85:83:95:88:92:1B:FF:B8:2B:0E:65:8E:0A:0F:41:D6:77:B6:1C:0F:61:E9:57:31:BA:BA:57
a=setup:actpass
a=mid:0
a=sendrecv
a=msid:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k 60e954e1-aa3a-417f-a318-f9712a8a1f3c
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=rtpmap:103 ISAC/16000
a=rtpmap:104 ISAC/32000
a=rtpmap:9 G722/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:106 CN/32000
a=rtpmap:105 CN/16000
a=rtpmap:13 CN/8000
a=rtpmap:110 telephone-event/48000
a=rtpmap:112 telephone-event/32000
a=rtpmap:113 telephone-event/16000
a=rtpmap:126 telephone-event/8000
a=ssrc:618251450 cname:rP1D9wZr3NEp/aEv
a=ssrc:618251450 msid:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k 60e954e1-aa3a-417f-a318-f9712a8a1f3c
a=ssrc:618251450 mslabel:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k
a=ssrc:618251450 label:60e954e1-aa3a-417f-a318-f9712a8a1f3c
m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 102 122 127 121 125 107 108 109 124 120 123 119 114 115 116
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:50VQ
a=ice-pwd:b6/176+swvZtv+ag5TuQ34mO
a=ice-options:trickle
a=fingerprint:sha-256 D1:C0:81:63:E2:85:83:95:88:92:1B:FF:B8:2B:0E:65:8E:0A:0F:41:D6:77:B6:1C:0F:61:E9:57:31:BA:BA:57
a=setup:actpass
a=mid:1
a=sendrecv
a=msid:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k afe3d0c2-2b1d-421c-a582-884a78386aa5
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:96 VP8/90000
a=rtpmap:97 rtx/90000
a=rtpmap:98 VP9/90000
a=rtpmap:99 rtx/90000
a=rtpmap:100 VP9/90000
a=rtpmap:101 rtx/90000
a=rtpmap:102 H264/90000
a=rtpmap:122 rtx/90000
a=rtpmap:127 H264/90000
a=rtpmap:121 rtx/90000
a=rtpmap:125 H264/90000
a=rtpmap:107 rtx/90000
a=rtpmap:108 H264/90000
a=rtpmap:109 rtx/90000
a=rtpmap:124 H264/90000
a=rtpmap:120 rtx/90000
a=rtpmap:123 H264/90000
a=rtpmap:119 rtx/90000
a=rtpmap:114 red/90000
a=rtpmap:115 rtx/90000
a=rtpmap:116 ulpfec/90000
a=ssrc-group:FID 2857721486 1595208456
a=ssrc:2857721486 cname:rP1D9wZr3NEp/aEv
a=ssrc:2857721486 msid:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k afe3d0c2-2b1d-421c-a582-884a78386aa5
a=ssrc:2857721486 mslabel:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k
a=ssrc:2857721486 label:afe3d0c2-2b1d-421c-a582-884a78386aa5
a=ssrc:1595208456 cname:rP1D9wZr3NEp/aEv
a=ssrc:1595208456 msid:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k afe3d0c2-2b1d-421c-a582-884a78386aa5
a=ssrc:1595208456 mslabel:Y4J0aef1P4IP81lfHtL3LZ6fPDcIHm8qFl4k
a=ssrc:1595208456 label:afe3d0c2-2b1d-421c-a582-884a78386aa5
