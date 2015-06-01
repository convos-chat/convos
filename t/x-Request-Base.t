use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Convos');

$t->app->routes->get('/x/request/base' => sub { $_[0]->render(text => $_[0]->url_for('/foo')) });
$t->get_ok('/x/request/base')->status_is(200)->content_is('/foo');
$t->get_ok('/x/request/base', {'X-Request-Base' => 'http://example.com/sub'})->status_is(200)->content_is('/sub/foo');

done_testing;
