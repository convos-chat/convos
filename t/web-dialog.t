use t::Helper;

my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/participants')->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$user->connection({name => 'localhost', protocol => 'irc'})->state('connected');

$t->get_ok('/api/connection/irc-not-found/dialog/not-found/participants')->status_is(404)
  ->json_is('/errors/0/message', 'Connection not found.');

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/participants')->status_is(500)
  ->json_is('/errors/0/message', 'Not connected.');

*Mojo::IRC::UA::channel_users = sub {
  my ($irc, $channel, $cb) = @_;
  $irc->$cb('', {test6851 => {mode => ''}, batman => {mode => '@'}});
};
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/participants')->status_is(200)
  ->json_has('/participants/0/mode')->json_has('/participants/0/name');

$user->connection({name => 'localhost', protocol => 'irc'})
  ->dialog({name => '#Convos', frozen => ''});
$t->get_ok('/api/dialogs')->status_is(200)->json_is(
  '/dialogs' => [
    {
      connection_id => 'irc-localhost',
      topic         => '',
      frozen        => '',
      name          => '#Convos',
      dialog_id     => '#convos',
      is_private    => 0,
    },
  ]
);

done_testing;
