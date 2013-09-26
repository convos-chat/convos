use t::Helper;

redis_do(
  [ hmset => 'user:doe', digest => 'E2G3goEIb8gpw', email => '' ],
  [ srem => 'user:doe:connections', 'localhost:6667' ],
  [ del => 'user:doe:connection:localhost:6667' ],
);

my $core = $t->app->core;
my($form, $tmp);

# login
$t->post_ok('/login', form => { login => 'doe', password => 'barbar' })->status_is(302);

{
  $t->get_ok('/settings')
    ->element_exists('form[action="/settings/connection"][method="post"]')
    ->element_exists('input[name="server"][id="server"]')
    ->element_exists('select[name="tls"]')
    ->text_is('select[name="tls"] option[value="0"]', 'No')
    ->text_is('select[name="tls"] option[value="1"]', 'TLS')
    ;

  $form = {
    server => 'localhost:6667',
    nick => 'ice_cool',
    channels => '#foo',
    tls => 1,
  };
  $t->post_ok('/settings/connection', form => $form)
    ->status_is('302')
    ->header_like('Location', qr{/settings$}, 'Redirect back to settings page')
    ;
}

{
  no warnings 'redefine';
  local *Mojo::IRC::connect = sub { Mojo::IOLoop->stop };
  $core->ctrl_start('doe', 'localhost:6667');
  Mojo::IOLoop->start;
  ok my $conn = $core->{connections}{doe}{'localhost:6667'}, 'connection added';
  is_deeply $conn->_irc->{tls}, {}, 'with tls';
}

done_testing;
