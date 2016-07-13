use t::Helper;

$ENV{CONVOS_HOME} = File::Spec->catdir(qw(t data convos-test-backend-file-messages));

my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$user->connection({name => 'localhost', protocol => 'irc'})->dialog({name => '#convos'});

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-01-01T00:00:00')
  ->status_is(401);
$t->get_ok('/api/notifications')->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-01-01T00:00:00')
  ->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 60, 'got max limit messages';

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-01-01T00:00:00&limit=1')
  ->status_is(200)->json_is(
  '/messages',
  [
    {
      message => 'The powernap package allows you to suspend servers which are not being used,',
      from    => 'mr22',
      ts      => '2014-08-22T10:23:50',
      type    => 'private',
    }
  ]
  );

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2014-06-21T14:12:10&limit=3&match=AppArmor'
  )->status_is(200)->json_is(
  '/messages',
  [
    {
      message => 'Unsure if AppArmor might be causing an issue? Don\'t disable it, use the',
      from    => 'jhthorsen',
      ts      => '2014-06-21T10:12:25',
      type    => 'private'
    }
  ]
  );

$t->get_ok('/api/notifications')->status_is(200)->json_is(
  '/notifications',
  [
    {
      connection_id => 'irc-localhost',
      dialog_id     => '#convos',
      from          => 'mr22',
      message       => 'If you know you typed a command or password wrong, you can use ctrl + u to',
      ts            => '2014-08-21T10:12:27',
      type          => 'private'
    }
  ]
);

done_testing;
