#!perl
use Mojo::JSON 'decode_json';
use Mojo::Util 'url_escape';
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';

my $t                  = t::Helper->t;
my $default_connection = 'irc://localhost:6123/%23convos';
$t->app->core->settings->default_connection(Mojo::URL->new($default_connection));
$t->app->core->settings->open_to_public(true);

$t->get_ok('/register')->status_is(200);
$t->get_ok('/register?uri=' . url_escape 'irc://irc.example.com:6123/%23convos')->status_is(200)
  ->content_like(qr{"conn_url":"irc:\\/\\/irc.example.com:6123\\/%23convos"});

$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

$t->get_ok('/chat')->status_is(200);

my $json = decode_json($t->tx->res->text =~ m!window\.__convos\s*=\s*([^;]+)!m ? $1 : '{}');
is $json->{api_url}, '/api', 'settings.api_url';
is $json->{contact}, 'mailto:root@localhost', 'settings.contact';
is $json->{open_to_public}, true, 'open_to_public';
is $json->{organization_name}, 'Convos',            'settings.organization_name';
is $json->{organization_url},  'https://convos.by', 'settings.organization_url';
ok $json->{base_url},          'settings.base_url';
ok $json->{default_connection}, 'settings.default_connection';
ok $json->{version},            'settings.version';
ok $json->{ws_url},             'settings.ws_url';
ok !$json->{user}, 'the user should not be part of the settings';

my $url = url_escape $default_connection;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!localhost!127.0.0.1!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!convos$!superduper!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(
  Location => '/settings/conversation?connection_id=irc-localhost&dialog_id=%23superduper');

$url =~ s!127.0.0.1!irc.example.com!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(
  Location => '/settings/connection?uri=irc%3A%2F%2Firc.example.com%3A6123%2F%2523superduper');

done_testing;
