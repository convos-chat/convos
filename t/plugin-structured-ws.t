use Mojo::Base -strict;

use Mojo::JSON 'j';
use Mojo::Util 'monkey_patch';
use Test::Mojo;
use Test::More;

use Mojolicious::Lite;
plugin 'Convos::Plugin::StructuredWS' =>
  {namespaces => ['MyApp::Controller'], spec => 'data://main/spec.json'};

my $t = Test::Mojo->new;
my ($res, %req);

$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/id', 0)
  ->json_message_is('/status', 400);
$res = j($t->message->[1]);
is_deeply([sort map { $_->{path} } @{$res->{errors}}],
  [qw(/data /id /method)], 'invalid use of protocol');

%req = (data => {email => 'super@man.com', password => 's3cret'}, id => 42, method => 'foo#bar');
$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/id', 42)
  ->json_message_is('/errors/0/message', 'No such resource.')->json_message_is('/status', 400);

$req{method} = 'user#login';
$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/id', 42)
  ->json_message_is('/errors/0/message', 'Unable to load controller.')
  ->json_message_is('/status',           500);

eval <<'HERE' or die $@;
package MyApp::Controller::User;
use Mojo::Base 'Mojolicious::Controller';
1;
HERE
$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/status', 500)
  ->json_message_is('/errors/0/message', 'Unable to dispatch to method.');

monkey_patch 'MyApp::Controller::User' => login => sub {
  my ($c, $args, $cb) = @_;
  $c->$cb({data => {email => $args->{email}}});
};
$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/id', 42)
  ->json_message_is('/data/email', 'super@man.com')->json_message_is('/status', 200);

delete $req{data}{email};
$t->websocket_ok('/channel')->send_ok({json => \%req})->message_ok->json_message_is('/id', 42)
  ->json_message_is('/errors/0/path', '/data/email')->json_message_is('/status', 400);

done_testing;

__DATA__
@@ spec.json
{
  "resources": {
    "user#login": {
      "parameters": {
        "type": "object",
        "required": ["email", "password"],
        "properties": {
          "email": {"type": "string"},
          "password": { "type": "string", "description": "User password" }
        }
      },
      "responses": {
        "200": {
          "schema": {
            "type": "object",
            "required": ["email"],
            "properties": {
              "email": {"type": "string"}
            }
          }
        }
      }
    }
  }
}
