#!perl
use Mojo::JSON 'decode_json';
use Mojo::Util 'url_escape';
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{CONVOS_DEFAULT_CONNECTION} ||= 'irc://localhost:6123/%23convos';
$ENV{CONVOS_INVITE_CODE} = '';

my $t = t::Helper->t;

$t->get_ok('/register')->status_is(200);
$t->get_ok('/register?uri=' . url_escape 'irc://irc.example.com:6123/%23convos')->status_is(200)
  ->content_like(qr{"conn_url":"irc:\\/\\/irc.example.com:6123\\/%23convos"});

$t->post_ok('/api/user/register', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->get_ok('/chat')->status_is(200);

my $json = decode_json($t->tx->res->text =~ m!window\.__convos\s*=\s*([^;]+)!m ? $1 : '{}');
is $json->{apiUrl},            '/api',                  'settings.apiUrl';
is $json->{contact},           'mailto:root@localhost', 'settings.contact';
is $json->{organization_name}, 'Convos',                'settings.organization_name';
is $json->{organization_url},  'http://convos.by',      'settings.organization_url';
ok $json->{baseUrl},           'settings.baseUrl';
ok $json->{default_connection}, 'settings.default_connection';
ok $json->{version},            'settings.version';
ok $json->{wsUrl},              'settings.wsUrl';
ok exists $json->{invite_code}, 'settings.invite_code';
ok !$json->{user}, 'the user should not be part of the settings';

my $url = url_escape $ENV{CONVOS_DEFAULT_CONNECTION};
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!localhost!127.0.0.1!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!convos$!superduper!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/add/conversation?connection_id=irc-localhost&dialog_id=%23superduper');

$url =~ s!127.0.0.1!irc.example.com!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(
  Location => '/add/connection?uri=irc%3A%2F%2Firc.example.com%3A6123%2F%2523superduper');

done_testing;
