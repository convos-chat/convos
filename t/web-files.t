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

my $asset  = Mojo::Asset::File->new({path => __FILE__});
my $fid_re = qr/\w{14,16}/;
my ($connection, $fid);

subtest initial => sub {
  $t->post_ok('/api/files', form => {file => {file => $asset}})->status_is(401);
  $t->get_ok('/api/files')->status_is(401);
  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
    ->status_is(200);
};

subtest 'upload' => sub {
  $t->post_ok('/api/files')->status_is(400)->json_is('/errors/0/path', '/file');

  $t->post_ok('/api/files', form => {file => {file => $asset}})->status_is(200)
    ->json_is('/files/0/ext', 't')->json_is('/files/0/filename', 'web-files.t')
    ->json_is('/files/0/uid', 1)->json_like('/files/0/id', qr{^$fid_re$})
    ->json_like('/files/0/saved', qr{^\d+-\d+})
    ->json_like('/files/0/url',   qr{^http.*/file/1/$fid_re$});

  $fid = $t->tx->res->json('/files/0/id');
  $t->get_ok("/file/1/$fid")->status_is(200)
    ->element_exists('.le-paste > pre.paste', 'pre.paste so LinkEmbedder can do the right thing')
    ->header_is('X-Provider-Name', 'ConvosApp')->text_is('h1', 'web-files.t')
    ->text_like('.cms-meta .cms-meta__date', qr{^\d+\.\s})
    ->content_like(qr{\<pre class="paste"\>.*use t::Helper}s);
  $t->get_ok("/file/1/$fid.t")->status_is(200)->header_is('Cache-Control', 'max-age=86400')
    ->content_like(qr{use t::Helper}s)->content_unlike(qr{\<pre class="paste"\>.*use t::Helper}s);

  $t->get_ok("/api/files/1/1000000000000000")->status_is(404);
  $t->get_ok("/file/1/1000000000000000")->status_is(404);
};

subtest 'set up connection' => sub {
  $connection = $user->connection({url => 'irc://localhost'});
  $server->client($connection)->server_event_ok('_irc_event_nick')
    ->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')->process_ok;
};

subtest 'handle_message_to_paste_p' => sub {
  my %send = (connection_id => $connection->id, conversation_id => 'superwoman', method => 'send');
  $send{message} = substr +(join('', map {chr} reverse 20 .. 126) x 13), 0, 512 * 3;
  $t->websocket_ok('/events')->send_ok({json => \%send})
    ->message_ok->json_message_is('/conversation_id', 'superwoman')
    ->json_message_is('/event', 'message')
    ->json_message_like('/message', qr{^http.*/file/1/$fid_re})->finish_ok;

  my $msg = Mojo::JSON::decode_json($t->message->[1]);
  my $url = Mojo::URL->new($msg->{message});
  isnt $url->path->[-1], $fid, 'paste does not have the same id as file';
  $t->get_ok($url->path->to_string)->status_is(200)
    ->text_is('h1', 'zyxwvutsrqponmlkjihgfedcba_.txt')
    ->element_exists(sprintf 'a[href$="%s.txt"]', $url->path->to_string)
    ->text_like('.cms-meta .cms-meta__date', qr{^\d+\.\s})
    ->content_like(qr{\<pre class="paste"\>~\}\|\{zyxwvutsrqponmlkjihgfedcba`_\^\]\\\[});
};

subtest 'iPhone default image name' => sub {
  $t->post_ok('/api/files', form => {file => {file => 't/data/image.jpg'}})->status_is(200)
    ->json_like('/files/0/filename', qr{^IMG_\d+\.jpg$});
  isnt $t->tx->res->json('/files/0/id'), $fid, 'image does not have the same id as file';
};

subtest 'embedded image' => sub {
  $fid = $t->tx->res->json('/files/0/id');
  my $url  = $t->tx->res->json('/files/0/url');
  my $name = $t->tx->res->json('/files/0/filename');
  $t->get_ok("/file/1/$fid")->element_exists(qq(meta[property="og:description"][content="$name"]))
    ->element_exists(qq(meta[property="og:image"][content="$url.jpg"]))
    ->element_exists(qq(main a[href="$url.jpg"]))->element_exists(qq(main a img[src="$url.jpg"]));

  $t->get_ok("/file/1/$fid.jpg")->header_is('Cache-Control', 'max-age=86400')
    ->header_is('Content-Type' => 'image/jpeg')->header_exists_not('Content-Disposition');
};

subtest 'binary' => sub {
  $t->post_ok('/api/files', form => {file => {file => 't/data/binary.bin'}})->status_is(200);
  my $fid  = $t->tx->res->json('/files/0/id');
  my $url  = $t->tx->res->json('/files/0/url');
  my $name = $t->tx->res->json('/files/0/filename');
  $t->get_ok("/file/1/$fid")->header_is('Cache-Control', 'max-age=86400')
    ->header_is('Content-Disposition', 'attachment; filename="binary.bin"')
    ->header_is('Content-Type' => 'application/octet-stream');
};

subtest 'svg with javasript' => sub {
  $t->post_ok('/api/files', form => {file => {file => 't/data/js.svg'}})->status_is(400)
    ->json_is('/errors/0/message', 'SVG contains script.');
};

subtest 'write_only' => sub {
  $t->post_ok('/api/files',
    form => {id => 'irc-localhost-key', file => {file => $asset}, write_only => true})
    ->status_is(200);
  $fid = $t->tx->res->json('/files/0/id');
  is $fid, 'irc-localhost-key', 'forced id';
  ok -e $t->app->core->home->child(qw(superman@example.com upload irc-localhost-key.data)),
    'file was uploaded';
  $t->get_ok("/file/1/$fid")->status_is(404);
};

subtest 'max_message_size' => sub {
  local $ENV{CONVOS_MAX_UPLOAD_SIZE} = 10;
  $t->post_ok('/api/files', form => {file => {file => $asset}})->status_is(400)
    ->json_is('/errors/0/message', 'Maximum message size exceeded');
};

subtest 'upload more files so we can do proper pagination testing' => sub {
  for ((sort grep /Convos/, values %INC)[1 .. 10]) {
    next if !-r or /Controller\/Files\.pm/;
    my $file = Mojo::Asset::File->new(path => $_);
    note $file->path;
    $t->post_ok('/api/files', form => {file => {file => $file}})->status_is(200)
      ->content_like(qr{"saved"});
  }
};

subtest 'list' => sub {
  my $files = sub { @{$t->tx->res->json->{files}} };
  $t->get_ok('/api/files')->status_is(200)->json_hasnt('/after')->json_hasnt('/next')
    ->json_hasnt('/prev')->json_has('/files/4')->json_has('/files/0/name')->json_has('/files/0/id')
    ->json_like('/files/0/saved', qr{^\d+-\d+-\d+T})->json_has('/files/0/size');
  my @ids = map { $_->{id} } $files->();
  is @ids, 14, 'got all files';

  note 'unknown';
  $t->get_ok('/api/files?limit=1&after=unknown')->status_is(200)->json_is('/files', [])
    ->json_hasnt('/after')->json_hasnt('/next')->json_hasnt('/prev');

  note 'limit';
  $t->get_ok('/api/files?limit=2')->status_is(200)->json_hasnt('/after')->json_is('/next', $ids[2])
    ->json_has('/files/0')->json_hasnt('/prev')->json_hasnt('/files/2');
  is int($files->()),                              2, 'got two files';
  is int(grep { $_->{id} eq $ids[2] } $files->()), 0, 'next is not in file list';

  note 'limit and after';
  $t->get_ok("/api/files?limit=3&after=$ids[5]")->status_is(200)->json_is('/after', $ids[5])
    ->json_is('/next', $ids[9])->json_is('/prev', $ids[2]);
  my $first = $t->tx->res->json->{files}[0]{id};
  my $next  = $t->tx->res->json->{next};
  my $prev  = $t->tx->res->json->{prev};
  is int($files->()),                              3, 'got three files';
  is int(grep { $_->{id} eq $ids[2] } $files->()), 0, 'after is not in file list';
  is int(grep { $_->{id} eq $next } $files->()),   0, 'next is not in file list';
  is int(grep { $_->{id} eq $prev } $files->()),   0, 'prev is not in file list';

  note 'go to prev';
  $t->get_ok("/api/files?limit=3&after=$prev")->status_is(200)->json_is('/after', $prev)
    ->json_is('/next', $first)->json_is('/files/0/id', $ids[3]);
};

done_testing;

__DATA__
@@ 149545306873033
{"author":"superman@example.com","content":"curl -s www.cpan.org\/modules\/02packages.details.txt","created_at":1495453068.73033}
