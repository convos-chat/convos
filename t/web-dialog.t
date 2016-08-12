use t::Helper;

my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/participants')->status_is(401);
$t->post_ok('/api/command',
  json => {connection_id => 'irc-not-found', dialog_id => 'not-found', command => "hey!"})
  ->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->post_ok('/api/command', json => {connection_id => 'irc-localhost', command => "/join #c"})
  ->status_is(404)->json_is('/errors/0/message', 'Connection not found.');

$user->connection({name => 'localhost', protocol => 'irc'})->state('connected');

no warnings qw(once redefine);
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };
$t->post_ok('/api/command', json => {connection_id => 'irc-localhost', command => "/join #Convos"})
  ->status_is(200)->json_is('/frozen', '')->json_is('/dialog_id', '#convos')
  ->json_is('/name', '#Convos')->json_is('/topic', '');

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

$t->post_ok('/api/command',
  json => {connection_id => 'irc-nope', dialog_id => 'nope', command => "hey!"})->status_is(404);
$t->post_ok('/api/command', json => {connection_id => 'irc-localhost', command => "hey!"})
  ->status_is(500)->json_is('/errors/0/message', 'Cannot send without target.');
$t->post_ok('/api/command',
  json => {connection_id => 'irc-localhost', dialog_id => '#convos', command => "hey!"})
  ->status_is(500)->json_is('/errors/0/message', 'Not connected.');

*Mojo::IRC::UA::write = sub { my ($irc, $str, $cb) = @_; $irc->$cb('') };
$t->post_ok('/api/command',
  json => {connection_id => 'irc-localhost', dialog_id => '#convos', command => "hey!"})
  ->status_is(200)->json_is('/command', 'hey!');

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

$user->get_connection('irc-localhost')->state('disconnected');
$t->post_ok('/api/command', json => {connection_id => 'irc-localhost', command => "/close #c"})
  ->status_is(200)->json_is('/command', '/close #c');

done_testing;
