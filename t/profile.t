use t::Helper;
use Mojo::JSON;
use Mojo::DOM;

redis_do(
  [hmset => 'user:doe',             digest => 'E2G3goEIb8gpw', email => 'e1@convos.by', avatar => 'a1@convos.by'],
  [sadd  => 'user:doe:connections', 'magnet'],
  [hmset => 'user:doe:connection:magnet', nick => 'doe'],
);

{
  diag 'test sidebar links';
  $t->get_ok('/convos')->status_is(302);
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
  $t->get_ok('/convos')->status_is(200)->element_exists('.sidebar a[href="/profile"]')
    ->element_exists('.sidebar a[href="/logout"]');
}

{
  diag 'test logout';
  $t->get_ok('/logout')->status_is(302);
  $t->get_ok('/convos')->status_is(302);
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
}

{
  diag 'test profile';
  $t->get_ok('/profile')->status_is(200)->element_exists('.sidebar a[href="/profile"]')
    ->element_exists('.sidebar a[href="/logout"]')->element_exists('a[href="http://gravatar.com"][target="_blank"]')
    ->element_exists('form[action="/profile"][method="post"]')
    ->element_exists('form input[name="email"][value="e1@convos.by"]')
    ->element_exists('form input[name="avatar"][value="a1@convos.by"]')->text_is('form .actions button', 'Update')
    ->text_is('form .actions a[href="/convos"][class="button"]', 'Cancel');

  $t->post_ok('/profile', form => {email => 'foo@', avatar => 'ba'})->status_is(400)
    ->element_exists('form .form-group.email .error')->element_exists('form .form-group.avatar .error');

  $t->post_ok('/profile', form => {avatar => 'fbusername', email => 'e2@convos.by'})->status_is(200)
    ->element_exists('form input[name="email"][value="e2@convos.by"]')
    ->element_exists('form input[name="avatar"][value="fbusername"]');
}

done_testing;
