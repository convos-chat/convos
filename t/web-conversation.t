#!perl
use lib '.';
use t::Helper;

my $t    = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$user->connection({name => 'localhost', protocol => 'irc'})->state(connected => '');

my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
$connection->_irc_event_privmsg({
  command => 'privmsg',
  prefix  => 'Supergirl!super.girl@i.love.debian.org',
  params  => ['#Convos', 'not a superdupersuperman?']
});
$connection->conversation({name => '#Convos', frozen => ''})->unread(42);
$t->get_ok('/api/conversations')->status_is(200)->json_is(
  '/conversations' => [
    {
      connection_id   => 'irc-localhost',
      conversation_id => '#convos',
      frozen          => '',
      name            => '#Convos',
      topic           => '',
      unread          => 42,
    },
  ]
);

$user->connection({name => 'example', protocol => 'irc'})
  ->conversation({name => '#superheroes', frozen => ''})->unread(34);
$t->get_ok('/api/user?connections=true&conversations=true')->status_is(200)->json_is(
  '/connections',
  [
    {
      connection_id       => 'irc-example',
      me                  => {},
      name                => 'example',
      on_connect_commands => [],
      protocol            => 'irc',
      state               => 'queued',
      url                 => 'irc://localhost',
      wanted_state        => 'connected',
    },
    {
      connection_id       => 'irc-localhost',
      me                  => {},
      name                => 'localhost',
      on_connect_commands => [],
      protocol            => 'irc',
      state               => 'connected',
      url                 => 'irc://localhost',
      wanted_state        => 'connected',
    }
  ],
  'user connections'
)->json_is(
  '/conversations',
  [
    {
      connection_id   => 'irc-localhost',
      conversation_id => '#convos',
      frozen          => '',
      name            => '#Convos',
      topic           => '',
      unread          => 42,
    },
    {
      connection_id   => 'irc-example',
      conversation_id => '#superheroes',
      frozen          => '',
      name            => '#superheroes',
      topic           => '',
      unread          => 34,
    }
  ],
  'user conversations'
)->json_hasnt('/notifications', 'user notifications');

$t->post_ok('/api/connection/irc-localhost/conversation/%23convos/read')->status_is(200);

done_testing;
