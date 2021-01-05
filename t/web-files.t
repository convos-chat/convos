#!perl
use lib '.';
use Convos::Util 'short_checksum';
use t::Helper;
use t::Server::Irc;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend::File';
my $server = t::Server::Irc->new->start;
my $t      = t::Helper->t;
my $user   = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

my $asset = Mojo::Asset::File->new({path => __FILE__});
$t->post_ok('/api/file', form => {file => {file => $asset}})->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

note 'upload';
$t->post_ok('/api/file')->status_is(400)->json_is('/errors/0/path', '/file');

my $fid_re = qr/\w{14,16}/;
$t->post_ok('/api/file', form => {file => {file => $asset}})->status_is(200)
  ->json_is('/files/0/ext', 't')->json_is('/files/0/filename', 'web-files.t')
  ->json_is('/files/0/uid', 1)->json_like('/files/0/id', qr{^$fid_re$})
  ->json_like('/files/0/saved', qr{^\d+-\d+})
  ->json_like('/files/0/url',   qr{^http.*/file/1/$fid_re$});

my $fid = $t->tx->res->json('/files/0/id');
$t->get_ok("/file/1/$fid")->status_is(200)
  ->element_exists('.le-paste > pre.paste', 'pre.paste so LinkEmbedder can do the right thing')
  ->header_is('X-Provider-Name', 'ConvosApp')->text_is('h1', 'web-files.t')
  ->text_like('.cms-date', qr{^\d+-\d+-\d+})
  ->content_like(qr{\<pre class="paste"\>.*use t::Helper}s);
$t->get_ok("/file/1/$fid.t")->status_is(200)->header_is('Cache-Control', 'max-age=86400')
  ->content_like(qr{use t::Helper}s)->content_unlike(qr{\<pre class="paste"\>.*use t::Helper}s);

$t->get_ok("/api/file/1/1000000000000000")->status_is(404);
$t->get_ok("/file/1/1000000000000000")->status_is(404);

note 'set up connection';
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
$server->client($connection)->server_event_ok('_irc_event_nick')->server_write_ok(['welcome.irc'])
  ->client_event_ok('_irc_event_rpl_welcome')->process_ok;

note 'handle_message_to_paste_p';
my %send = (connection_id => $connection->id, conversation_id => 'superwoman', method => 'send');
$send{message} = substr +(join('', map {chr} reverse 20 .. 126) x 13), 0, 512 * 3;
$t->websocket_ok('/events')->send_ok({json => \%send})
  ->message_ok->json_message_is('/conversation_id', 'superwoman')
  ->json_message_is('/event', 'message')->json_message_like('/message', qr{^http.*/file/1/$fid_re})
  ->finish_ok;

my $msg = Mojo::JSON::decode_json($t->message->[1]);
my $url = Mojo::URL->new($msg->{message});
isnt $url->path->[-1], $fid, 'paste does not have the same id as file';
$t->get_ok($url->path->to_string)->status_is(200)->text_is('h1', 'zyxwvutsrqponmlkjihgfedcba_.txt')
  ->text_like('.cms-date', qr{^\d+-\d+-\d+})
  ->content_like(qr{\<pre class="paste"\>~\}\|\{zyxwvutsrqponmlkjihgfedcba`_\^\]\\\[});

note 'back compat paste route';
my $paste = $user->core->home->child(qw(superman@example.com upload 149545306873033))
  ->spurt(Mojo::Loader::data_section('main', '149545306873033'));
my $user_sha1 = substr Mojo::Util::sha1_sum('superman@example.com'), 0, 20;

ok -e $paste, 'legacy paste exists';
$t->get_ok("/paste/10000000000000000000/149545306873033")->status_is(404);
$t->get_ok("/paste/$user_sha1/100000000000000")->status_is(404);
$t->get_ok("/paste/$user_sha1/149545306873033")->status_is(200)
  ->header_is('Cache-Control', 'max-age=86400')->text_is('h1', 'paste.txt')
  ->content_like(qr{\<pre class="paste"\>.*curl -s www}s);

ok !-e $paste, 'legacy paste was moved';
$t->get_ok("/paste/$user_sha1/149545306873033")->status_is(200, '200 OK after moved');

note 'iPhone default image name';
$t->post_ok('/api/file', form => {file => {file => 't/data/image.jpg'}})->status_is(200)
  ->json_like('/files/0/filename', qr{^IMG_\d+\.jpg$});
isnt $t->tx->res->json('/files/0/id'), $fid, 'image does not have the same id as file';

note 'embedded image';
my $name;
$fid  = $t->tx->res->json('/files/0/id');
$url  = $t->tx->res->json('/files/0/url');
$name = $t->tx->res->json('/files/0/filename');
$t->get_ok("/file/1/$fid")->element_exists(qq(meta[property="og:description"][content="$name"]))
  ->element_exists(qq(meta[property="og:image"][content="$url.jpg"]))
  ->element_exists(qq(main a[href="$url.jpg"]))->element_exists(qq(main a img[src="$url.jpg"]));

$t->get_ok("/file/1/$fid.jpg")->header_is('Cache-Control', 'max-age=86400')
  ->header_is('Content-Type' => 'image/jpeg')->header_exists_not('Content-Disposition');

note 'binary';
$t->post_ok('/api/file', form => {file => {file => 't/data/binary.bin'}})->status_is(200);
$fid  = $t->tx->res->json('/files/0/id');
$url  = $t->tx->res->json('/files/0/url');
$name = $t->tx->res->json('/files/0/filename');
$t->get_ok("/file/1/$fid")->header_is('Cache-Control', 'max-age=86400')
  ->header_is('Content-Disposition', 'attachment; filename="binary.bin"')
  ->header_is('Content-Type' => 'application/octet-stream');

note 'write_only';
$t->post_ok('/api/file',
  form => {id => 'irc-localhost-key', file => {file => $asset}, write_only => true})
  ->status_is(200);
$fid = $t->tx->res->json('/files/0/id');
is $fid, 'irc-localhost-key', 'forced id';
ok -e $t->app->core->home->child(qw(superman@example.com upload irc-localhost-key.data)),
  'file was uploaded';
$t->get_ok("/file/1/$fid")->status_is(404);

note 'max_message_size';
$ENV{CONVOS_MAX_UPLOAD_SIZE} = 10;
$t->post_ok('/api/file', form => {file => {file => $asset}})->status_is(400)
  ->json_is('/errors/0/message', 'Maximum message size exceeded');

done_testing;

__DATA__
@@ 149545306873033
{"author":"superman@example.com","content":"curl -s www.cpan.org\/modules\/02packages.details.txt","created_at":1495453068.73033}
