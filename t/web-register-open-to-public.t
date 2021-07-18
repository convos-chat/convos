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
$t->get_ok('/register?uri=' . url_escape 'irc://irc.example.com:6123/%23convos')->status_is(200);

$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

$t->get_ok('/chat')->status_is(200)
  ->element_exists(qq(meta[name="convos:base_url"][content^="http://"]))
  ->element_exists(qq(meta[name="convos:existing_user"][content="no"]))
  ->element_exists(qq(meta[name="convos:first_user"][content="no"]))
  ->element_exists(qq(meta[name="convos:open_to_public"][content="yes"]))
  ->element_exists(qq(meta[name="convos:status"][content="200"]))
  ->element_exists(qq(meta[name="description"][content^="A chat application"]));

my $url = url_escape($t->get_ok('/api/user')->status_is(200)->tx->res->json->{default_connection});
note "uri=$url";
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!localhost!127.0.0.1!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(Location => '/chat/irc-localhost/%23convos');

$url =~ s!convos$!superduper!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(
  Location => '/settings/conversation?connection_id=irc-localhost&conversation_id=%23superduper');

$url =~ s!127.0.0.1!irc.example.com!;
$t->get_ok("/register?uri=$url")->status_is(302)
  ->header_is(
  Location => '/settings/connection/add?uri=irc%3A%2F%2Firc.example.com%3A6123%2F%2523superduper');

done_testing;
