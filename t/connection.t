use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

my $form;

redis_do(
  [hmset => 'user:doe',             digest => 'E2G3goEIb8gpw', email => 'e1@convos.by', avatar => 'a1@convos.by'],
  [sadd  => 'user:doe:connections', 'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe', server => 'irc.perl.org', tls => 1],
);

{
  $t->get_ok('/magnet')->status_is(302);
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
  $t->get_ok('/magnet')->status_is(200)->element_exists('.sidebar a[href="/connection/magnet/edit"]')
    ->element_exists('.sidebar a[href="/connection/magnet/delete"]');
}

{
  $t->get_ok('/connection/magnet/edit')->status_is(200)->element_exists('.sidebar a[href="/connection/magnet/edit"]')
    ->element_exists('.sidebar a[href="/connection/magnet/delete"]')
    ->element_exists('form[action="/connection/magnet/edit"][method="post"]')
    ->element_exists('form input[name="server"][value="irc.perl.org"]')
    ->element_exists('form input[name="nick"][value="doe"]')
    ->element_exists('form input[name="tls"][value="1"][checked="checked"]')->text_is('form .actions button', 'Update');

  $form = {nick => '123456789012345678901234567890abcdef'};
  $t->post_ok('/connection/magnet/edit', form => $form)->element_exists('.sidebar a[href="/connection/magnet/edit"]')
    ->element_exists('.sidebar a[href="/connection/magnet/delete"]')->element_exists('.server .error')
    ->element_exists('.nick .error')->text_is('form .actions button', 'Update');

  $form = {server => 'irc.perl.org', nick => 'yay', tls => 1};
  $t->post_ok('/connection/magnet/edit', form => $form)->status_is(302)->header_is(Location => '/magnet');
}

{
  $t->get_ok('/connection/magnet/delete')->status_is(200)
    ->element_exists('form[action="/connection/magnet/delete"][method="post"]')->text_is('form .actions button', 'Yes')
    ->text_is('form .actions a[href="/magnet"]', 'No');

  $t->post_ok('/connection/magnet/delete')->status_is(302)->header_is(Location => '/convos');
}

done_testing;
