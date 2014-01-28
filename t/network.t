use t::Helper;
use Convos::Upgrader;
my $form;

plan skip_all =>
  'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.'
  unless $ENV{REDIS_TEST_DATABASE};

redis_do([hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => ''], [del => 'user:doe:connections'],);

{
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302)
    ->header_like('Location', qr{/wizard$});
}

{
  $t->get_ok('/network/add')->status_is(200)->element_exists('input[type="hidden"][name="referrer"]')
    ->element_exists('input[type="text"][name="name"]')->element_exists('input[type="text"][name="server"]')
    ->element_exists('input[type="text"][name="home_page"]')->element_exists('input[type="checkbox"][name="tls"]')
    ->element_exists('input[type="checkbox"][name="password"]')
    ->element_exists('input[type="checkbox"][name="default"]')
    ->text_is('div.actions button[type="submit"]', 'Add network')->text_is('div.actions a', 'Cancel');
}

{
  $form = {name => 'cool_network', referrer => '/wizard', server => 'irc.perl.org:foo',};
  $t->post_ok('/network/add', form => $form)->status_is(400)->element_exists('.form-group.name .error')
    ->element_exists('.form-group.server .error')->text_is('div.actions a[href="/wizard"]', 'Cancel');

  $form->{name}   = 'cool-network-123';
  $form->{server} = 'irc.perl.org';
  $t->post_ok('/network/add', form => $form)->status_is(302)->header_like('Location', qr{/wizard$});

  $t->get_ok('/wizard')->status_is(200)->element_exists('select[name="name"] option[value="cool-network-123"]')
    ->element_exists('select[name="name"] option[value="magnet"][data-channels="#convos"][selected="selected"]');
}

{
  delete $form->{name};
  $form->{default}  = 1;
  $form->{password} = 1;
  $t->post_ok('/network/cool-network-123/edit', form => $form)->status_is(302);

  $t->get_ok($t->tx->res->headers->location)->status_is(200)->element_exists_not('input[name="name"]')
    ->element_exists('input[type="text"][name="server"][value="irc.perl.org:6667"]')
    ->element_exists('input[type="text"][name="home_page"]')->element_exists('input[type="checkbox"][name="tls"]')
    ->element_exists('input[type="checkbox"][name="password"][checked]')
    ->element_exists('input[type="checkbox"][name="default"][checked]')
    ->text_is('div.actions button[type="submit"]', 'Update network');

  $t->get_ok('/wizard')->element_exists('select[name="name"] option[value="cool-network-123"][selected="selected"]')
    ->element_exists('select[name="name"] option[value="magnet"][data-channels="#convos"]');

  $t->get_ok('/network/not-here/edit')->status_is(404);
}

done_testing;
