use t::Helper;
use Mojo::JSON;
use Mojo::DOM;
use File::Basename 'dirname';
use File::Path 'make_path';
use File::Spec;

my @ctrl;
$t->app->core->start;
is_deeply(redis_do('keys', 'user:doe*'), [], 'user:doe keys');

{
  no warnings 'redefine';
  *Convos::Core::ctrl_stop = sub { shift; push @ctrl, stop => @_ };
}

redis_do(
  [hmset => 'user:doe',             digest => 'E2G3goEIb8gpw', email => 'e1@convos.by', avatar => 'a1@convos.by'],
  [sadd  => 'user:doe:connections', 'profirc'],
  [hmset => 'user:doe:connection:profirc', nick => 'doe', state => 'disconnected'],
);

{
  diag 'test sidebar links';
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
  $t->get_ok('/profirc')->status_is(200)->element_exists('.sidebar a[href="/profile"]')
    ->element_exists('.sidebar a[href="/logout"]');
}

{
  diag 'test logout';
  $t->get_ok('/logout')->status_is(302);
  $t->post_ok('/login', form => {login => 'doe', password => 'barbar'})->status_is(302);
}

{
  diag 'test profile';
  $t->get_ok('/profile')->status_is(200)->element_exists('.sidebar a[href="/profile"]')
    ->element_exists('.sidebar a[href="/logout"]')->element_exists('a[href="http://gravatar.com"][target="_blank"]')
    ->element_exists('form[action="/profile"][method="post"]')
    ->element_exists('form input[name="email"][value="e1@convos.by"]')
    ->element_exists('form input[name="avatar"][value="a1@convos.by"]')->text_is('form .actions button', 'Update')
    ->text_is('form .actions a[href="/"][class="button"]', 'Cancel');

  $t->post_ok('/profile', form => {email => 'foo@', avatar => 'ba'})->status_is(400)
    ->element_exists('form .form-group.email .error')->element_exists('form .form-group.avatar .error');

  $t->post_ok('/profile', form => {avatar => 'fbusername', email => 'e2@convos.by'})->status_is(200)
    ->element_exists('form input[name="email"][value="e2@convos.by"]')
    ->element_exists('form input[name="avatar"][value="fbusername"]');
}

{
  diag 'test delete profile';
  my $log_file = File::Spec->catfile(qw( irc_logs_test doe profirc whatever ));

  is_deeply(\@ctrl, [], 'no instructions sent yet');

  $t->get_ok('/profile/delete')->element_exists('form[action="/profile/delete"][method="post"]')
    ->element_exists('button.confirm');

  make_path(dirname($log_file));
  Mojo::Util::spurt('whatever', $log_file);
  ok -e $log_file, 'dummy log_file was created';

  $t->post_ok('/profile/delete', form => {})->status_is(302)->header_is('Location', '/');
  is_deeply(redis_do('keys', 'user:doe*'), [], 'user:doe keys after delete');

  is_deeply(\@ctrl, [qw( stop doe profirc )], 'stopped connection');
  ok !-e $log_file, 'dummy log_file was removed';
}

done_testing;
