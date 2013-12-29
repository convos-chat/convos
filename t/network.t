use t::Helper;
my $form;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ del => 'user:doe:connections' ],
);

{
  $t->post_ok('/login', form => { login => 'doe', password => 'barbar' })
    ->status_is(302)
    ->header_like('Location', qr{/wizard$});
    ;
}

{
  $t->get_ok('/network/add')
    ->status_is(200)
    ->element_exists('input[type="hidden"][name="referrer"]')
    ->element_exists('input[type="text"][name="name"]')
    ->element_exists('input[type="text"][name="server"]')
    ->element_exists('input[type="text"][name="port"]')
    ->element_exists('input[type="text"][name="home_page"]')
    ->element_exists('select[name="tls"]')
    ->text_is('div.actions button[type="submit"]', 'Add network')
    ->text_is('div.actions a', 'Cancel')
    ;
}

{
  $form = {
    name => 'cool_network',
    referrer => '/wizard',
    server => 'irc.perl.org:1234',
    tls => 0,
  };
  $t->post_ok('/network/add', form => $form)
    ->status_is(400)
    ->element_exists('.form-group.name .error')
    ->element_exists('.form-group.server .error')
    ->text_is('div.actions a[href="/wizard"]', 'Cancel')
    ;

  $form->{name} = 'cool-network-123';
  $form->{server} = 'irc.perl.org';
  $t->post_ok('/network/add', form => $form)
    ->status_is(302)
    ->header_like('Location', qr{/wizard$});
    ;
}

{
  $t->get_ok('/wizard')
    ->status_is(200)
    ->element_exists('select[name="network"] option[value="cool-network-123"]')
    ;
}

done_testing;
