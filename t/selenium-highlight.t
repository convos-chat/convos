use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, login => 1});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');

my $n_highlight = 0;

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#test"]') });
$t->click_ok('.convos-main-menu [href="#help"]', 'unfocus test channel');

$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['#test', 'What about a normal message in a channel?'],
  }
);

$t->wait_until(
  sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#test"] .n-unread') });
$t->live_text_is('.convos-main-menu [href="#chat/irc-default/#test"] .n-unread',
  1, 'test dialog unread++, no notifications, no highlight');

$t->click_ok('.convos-main-menu [href="#chat/irc-default/#test"]');
$t->live_element_exists_not('.convos-main-menu [href="#chat/irc-default/#test"] .n-unread',
  'clear unread on focus');
$t->live_element_exists_not('.convos-main-menu [href="#chat/irc-default/batgirl"]',
  'no messages from batgirl');

$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['#test', 'What about a normal message in a channel?'],
  }
);

$t->live_element_exists_not(
  '.convos-main-menu [href="#chat/irc-default/#test"] .n-unread',
  'test dialog unread is not increased, because of focus'
);

{
  $connection->_fallback(
    {
      command  => '266',
      event    => 'RPL_GLOBALUSERS',
      params   => ['', 'Current global users: 23  Max: 82'],
      prefix   => 'hybrid8.debian.local',
      raw_line => ":hybrid8.debian.local 266 $NICK :Current global users: 23  Max: 82"
    }
  );
  local $TODO = 'should it not increase?';
  $t->live_text_is('.convos-main-menu [href="#chat/irc-default/"] .n-unread',
    1, 'server dialog unread++, no notifications, no highlight');
}

$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => [$NICK, 'What about a private message?'],
  }
);

$t->wait_until(
  sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/batgirl"] .n-unread') });
$t->live_text_is('.convos-main-menu [href="#chat/irc-default/batgirl"] .n-unread',
  1, 'batgirl dialog unread++, desktop notifications++');
t::Selenium->desktop_notification_is($t, ['batgirl', 'What about a private message?']);

$n_highlight++;
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => [$NICK, "What if you, $NICK, are mentioned in a private dialog?"],
  }
);

$t->wait_until(sub { $_->find_element('.convos-header-links .n-notifications') });
$t->live_text_is('.convos-main-menu [href="#chat/irc-default/batgirl"] .n-unread',
  2, 'batgirl dialog unread++, desktop notifications++, got mentioned');
t::Selenium->desktop_notification_is($t,
  ["batgirl", "What if you, $NICK, are mentioned in a private dialog?"]);

$t->click_ok('.convos-main-menu [href="#chat/irc-default/batgirl"]');
$t->live_element_exists_not('.convos-main-menu [href="#chat/irc-default/batgirl"] .n-unread',
  'clear unread on focus');

note 'unread count is increased, but nothing else';
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ["#test", 'who is strongest: supergirl or wonderwoman?'],
  }
);

$t->live_text_is('.convos-main-menu [href="#chat/irc-default/#test"] .n-unread',
  1, 'test dialog unread++ on message');

$connection->$_(
  {event => 'part', prefix => 'batgirl!batgirl@i.love.debian.org', params => ["#test", $_]})
  for qw(_event_join _event_kick _event_part _event_quit);

$t->live_text_is('.convos-main-menu [href="#chat/irc-default/#test"] .n-unread',
  1, 'test dialog unread unchanged on join, kick, part and quit');

note 'desktop notification because nick is highlighted';
$n_highlight++;
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ["#test", "Are you here $NICK?"],
  }
);

$t->live_text_is('.convos-header-links .n-notifications', $n_highlight);
$t->click_ok('[href="#notifications"]');
$t->click_ok('[href="#mark-as-read"]');
$t->live_element_exists_not('.convos-header-links .n-notifications');
t::Selenium->desktop_notification_is($t, ["batgirl", "Are you here $NICK?"]);
t::Selenium->desktop_notification_is($t, undef);

t::Selenium->browser_log($t);

done_testing;
