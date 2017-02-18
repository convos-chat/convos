use lib '.';
use t::Helper;

my $t    = t::Helper->t;
my $ws   = t::Helper->t($t->app);
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;
my $connection       = $user->connection({name => 'localhost', protocol => 'irc'});
my $channel          = $connection->dialog({name => '#convos'});
my $stop_at_n_events = 0;
my @events;

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$ws->ua->cookie_jar($t->ua->cookie_jar);
$ws->websocket_ok('/events');
$ws->tx->on(json => sub { push(@events, $_[1]) >= $stop_at_n_events and Mojo::IOLoop->stop });

$t->get_ok('/api/notifications')->status_is(200);
my $n = @{$t->tx->res->json->{notifications}};
my $pm = $connection->dialog({name => 'batgirl'});

$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['superman', 'Hey! Do you get any notifications?'],
  }
);
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['superman', 'Hey superman! not even now?'],
  }
);
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['#convos', 'But... superman, what about in a channel?'],
  }
);
$connection->_event_privmsg(
  {
    event  => 'privmsg',
    prefix => 'batgirl!batgirl@i.love.debian.org',
    params => ['#convos', 'Or what about a normal message in a channel?'],
  }
);

$stop_at_n_events = 4;
$ws->ua->ioloop->start;

$t->get_ok('/api/notifications')->status_is(200);
is @{$t->tx->res->json->{notifications}}, $n + 1, 'only one new notification';
is int(grep { $_->{highlight} } @events),  2, 'marked as highlight';
is int(grep { !$_->{highlight} } @events), 2, 'not marked as highlight';

done_testing;
