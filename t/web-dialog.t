use lib '.';
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

no warnings qw(once redefine);
*Mojo::IRC::UA::channel_users = sub {
  my ($irc, $channel, $cb) = @_;
  $irc->$cb('', {test6851 => {mode => ''}, batman => {mode => '@'}});
};
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/participants')->status_is(200)
  ->json_has('/participants/0/mode')->json_has('/participants/0/name');

my $last_active = Mojo::Date->new(1471623050)->to_datetime;
my $last_read   = Mojo::Date->new(1471623058)->to_datetime;
my $connection  = $user->connection({name => 'localhost', protocol => 'irc'});
$connection->_irc->emit(
  irc_privmsg => {
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['#Convos', 'not a superdupersuperman?']
  }
);
$connection->dialog({name => '#Convos', frozen => ''})->last_read($last_read)
  ->last_active($last_active);
$t->get_ok('/api/dialogs')->status_is(200)->json_is(
  '/dialogs' => [
    {
      connection_id => 'irc-localhost',
      dialog_id     => '#convos',
      frozen        => '',
      is_private    => 0,
      name          => '#Convos',
      last_active   => '2016-08-19T16:10:50Z',
      last_read     => '2016-08-19T16:10:58Z',
      stash         => {},
      topic         => '',
      unread        => 1,
    },
  ]
);

$user->connection({name => 'example', protocol => 'irc'})
  ->dialog({name => '#superheroes', frozen => ''})->last_read($last_read)
  ->last_active($last_active);
$t->get_ok('/api/user?connections=true&dialogs=true')->status_is(200)->json_is(
  '/connections',
  [
    {
      connection_id       => 'irc-example',
      me                  => {},
      name                => 'example',
      on_connect_commands => [],
      protocol            => 'irc',
      state               => 'queued',
      url                 => 'irc://localhost:6667',
    },
    {
      connection_id       => 'irc-localhost',
      me                  => {},
      name                => 'localhost',
      on_connect_commands => [],
      protocol            => 'irc',
      state               => 'connected',
      url                 => 'irc://localhost:6667?nick=superman',
    }
  ],
  'user connections'
  )->json_is(
  '/dialogs',
  [
    {
      connection_id => 'irc-localhost',
      dialog_id     => '#convos',
      frozen        => '',
      is_private    => 0,
      name          => '#Convos',
      last_active   => '2016-08-19T16:10:50Z',
      last_read     => '2016-08-19T16:10:58Z',
      stash         => {},
      topic         => '',
      unread        => 1,
    },
    {
      connection_id => 'irc-example',
      dialog_id     => '#superheroes',
      frozen        => '',
      is_private    => 0,
      last_active   => '2016-08-19T16:10:50Z',
      last_read     => '2016-08-19T16:10:58Z',
      name          => '#superheroes',
      stash         => {},
      topic         => '',
      unread        => 0,
    }
  ],
  'user dialogs'
  )->json_hasnt('/notifications', 'user notifications');

done_testing;
