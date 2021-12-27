#!perl
BEGIN {
  $ENV{MOJO_MODE}          = 'production';
  $ENV{MOJO_REVERSE_PROXY} = 1;
}

use lib '.';
use t::Helper;

my $t = t::Helper->t;
$t->app->log->level('fatal');

$t->app->routes->get(
  '/t/base-url' => sub {
    my $c        = shift;
    my $base_url = $c->app->core->settings->base_url;
    $c->render(
      json => {
        base_url    => $base_url,
        url_for     => $c->url_for('/foo/bar'),
        web_url     => $c->app->core->web_url('/foo/bar')->to_abs,
        web_url_rel => $c->app->core->web_url('/foo/bar')
      }
    );
  }
);

$t->app->routes->get('/t/request-base' => sub { $_[0]->render(text => $_[0]->url_for('/foo')) });

$t->get_ok('/t/request-base?x=1')->status_is(200)->content_is('/foo');
$t->get_ok('/t/request-base?x=1', {'X-Request-Base' => 'http://example.com/sub'})->status_is(200)
  ->content_is('/sub/foo');

$t->get_ok('/t/base-url?x=2', {'X-Request-Base' => 'http://example.com/sub'})->status_is(200)
  ->json_is('/base_url', 'http://example.com/sub')->json_is('/url_for', '/sub/foo/bar')
  ->json_is('/web_url',  'http://example.com/sub/foo/bar')->json_is('/web_url_rel', '/sub/foo/bar');

$t->get_ok('/t/base-url?x=3')->status_is(200)->json_like('/base_url', qr{^http://.*:\d+/$})
  ->json_is('/url_for',     '/foo/bar')->json_like('/web_url', qr{^http://.*:\d+/foo/bar$})
  ->json_is('/web_url_rel', '/foo/bar');

$ENV{CONVOS_REVERSE_PROXY} = 0;
$t->get_ok('/t/base-url?x=4', {'X-Request-Base' => 'http://example.com/sub'})->status_is(500)
  ->content_like(qr{CONVOS_REVERSE_PROXY});

$ENV{CONVOS_REQUEST_BASE} = 'https://convos.chat/demo';
$t->get_ok('/t/base-url?x=5')->status_is(200)->json_is('/url_for', '/demo/foo/bar')
  ->json_is('/web_url_rel', '/demo/foo/bar');

done_testing;
