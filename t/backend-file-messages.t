#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;
use Convos::Date;

BEGIN {
  # CONVOS_TIME=2020-08-31T23:54:00 prove -vl t/backend-file-messages.t
  my $time = Convos::Date->parse($ENV{CONVOS_TIME} || time)->epoch;
  *CORE::GLOBAL::time = sub () {$time};
}

t::Helper->subprocess_in_main_process;

my $t = t::Helper->t;
File::Path::remove_tree($t::Helper::CONVOS_HOME);
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

my $connection   = $user->connection({name => 'localhost', protocol => 'irc'});
my $conversation = $connection->conversation({name => '#convos'});

my $ts_re = qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;

note 'not logged in';
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages')->status_is(401);
$t->get_ok('/api/notifications')->status_is(401);

note 'no messages';
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages')->status_is(200)
  ->json_is('', {messages => []});

my $t0 = Convos::Date->parse(time - (time % 60));
$connection->emit(message => $conversation => $_) for t::Helper->messages($t0->epoch);

note 'limit=1';
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages?limit=1')->status_is(200)
  ->json_is('/after',           undef)->json_is('/before', $t->tx->res->json->{messages}[0]{ts})
  ->json_is('/messages/0/from', 'toad')->json_is('/messages/0/message', '80 bead');
num_messages_is($t, 1, 'limit=1');

note "before=2018-01-01T00:39:00";
$t->get_ok(
  '/api/connection/irc-localhost/conversation/%23convos/messages?before=2018-01-01T00:39:00')
  ->status_is(200)->json_is('', {messages => []}, 'zero messages');

note 'before=now';
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages')->status_is(200)
  ->json_is('/after', undef)->json_is('/before', $t->tx->res->json->{messages}[0]{ts})
  ->json_like('/messages/0/ts', $ts_re)->json_is('/messages/0/highlight', false)
  ->json_is('/messages/0/type',     'private')->json_is('/messages/0/from', 'industry')
  ->json_is('/messages/0/message',  '21 bed')->json_is('/messages/59/from', 'toad')
  ->json_is('/messages/59/message', '80 bead');
num_messages_is($t, 60, 'no query');

$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages?limit=100')
  ->status_is(200);
num_messages_is($t, 81, 'limit=100');

my $after  = Convos::Date->parse($t->tx->res->json('/messages/13/ts'));
my $before = Convos::Date->parse($t->tx->res->json('/messages/15/ts'));
note "before=$before";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?before=$before")
  ->json_is('/after', undef)->json_is('/before', undef)->status_is(200)
  ->json_is('/messages/0/from',  'river')->json_is('/messages/0/message',  '0 pencil')
  ->json_is('/messages/14/from', 'anger')->json_is('/messages/14/message', '14 fowl');
num_messages_is($t, 15, "before=$before");

note "before=$before, limit=10";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?before=$before&limit=9")
  ->status_is(200)->json_is('/after', undef)
  ->json_is('/before', $t->tx->res->json->{messages}[0]{ts})->json_is('/messages/0/from', 'insect')
  ->json_is('/messages/0/message', '6 cap')->json_is('/messages/8/from', 'anger')
  ->json_is('/messages/8/message', '14 fowl');
num_messages_is($t, 9, "before=$before");

note "after=$after";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?after=$after")
  ->status_is(200)->json_is('/after', $t->tx->res->json->{messages}[-1]{ts})
  ->json_is('/before',              undef)->json_is('/messages/0/from', 'anger')
  ->json_is('/messages/0/message',  '14 fowl')->json_is('/messages/59/from', 'boundary')
  ->json_is('/messages/59/message', '73 boot');
num_messages_is($t, 60, "after=$after");

note "after=$after, limit=29";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?after=$after&limit=29")
  ->status_is(200)->json_is('/after', $t->tx->res->json->{messages}[-1]{ts})
  ->json_is('/before',              undef)->json_is('/messages/0/from', 'anger')
  ->json_is('/messages/0/message',  '14 fowl')->json_is('/messages/28/from', 'blade')
  ->json_is('/messages/28/message', '42 level');
num_messages_is($t, 29, "after=$after, limit=29");

note 'match';
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages?limit=1&match=pot')
  ->status_is(200)->json_is('/messages/0/message', '47 potato');
num_messages_is($t, 1, "match=pot, limit=1");
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages?match=pot')
  ->status_is(200)->json_is('/messages/0/message', '35 pot')
  ->json_is('/messages/1/message', '47 potato');
num_messages_is($t, 2, "match=pot");

note "after=$after, before=$before";
$t->get_ok(
  "/api/connection/irc-localhost/conversation/%23convos/messages?after=$after&before=$before")
  ->status_is(200)->json_is('/messages/0/from', 'anger')->json_is('/messages/0/message', '14 fowl');
num_messages_is($t, 1, "after=$after->datetime, before=$before");

my $around = $after;
note "around=$after";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?around=$around")
  ->status_is(200)->json_is('/messages/0/from', 'river')
  ->json_is('/messages/0/message',  '0 pencil')->json_is('/messages/72/from', 'change')
  ->json_is('/messages/72/message', '72 pear');
num_messages_is($t, 73, "around=$around");

note "around=$after, limit=10";
$t->get_ok("/api/connection/irc-localhost/conversation/%23convos/messages?around=$around&limit=10")
  ->status_is(200)->json_is('/after', $t->tx->res->json->{messages}[-1]{ts})
  ->json_is('/before',           $t->tx->res->json->{messages}[0]{ts})
  ->json_is('/messages/0/from',  'teaching')->json_is('/messages/0/message', '3 trade')
  ->json_is('/messages/19/from', 'shoe')->json_is('/messages/19/message', '22 sky');
num_messages_is($t, 20, "around=$around, limit=10");

note "around=$after, few messages";
my $pm = $connection->conversation({name => 'superwoman'});
$connection->emit(message => $pm => $_) for (t::Helper->messages($t0->epoch))[11 .. 20];
$t->get_ok("/api/connection/irc-localhost/conversation/superwoman/messages?around=$around")
  ->status_is(200)->json_is('/after', undef)->json_is('/before', undef)
  ->json_is('/messages/0/from', 'machine')->json_is('/messages/0/message', '11 dog')
  ->json_is('/messages/9/from', 'regret')->json_is('/messages/9/message', '20 men');
num_messages_is($t, 10, "around=$around, few messages");

note 'match unicode';
$connection->emit(
  message => $conversation => {
    from      => 'someone',
    highlight => false,
    message   => q(the character æ is unicode),
    ts        => time,
    type      => 'private',
  }
);

$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages?limit=1&match=æ')
  ->status_is(200)->json_is('/messages/0/message', q(the character æ is unicode));

note
  'As documented in Time::Piece, doing month math at the end of the month doesn\'t always do what you expect - @jberger';
$conversation = $connection->conversation({name => '#subtracting_months'});
$connection->emit(message => $conversation => $_) for t::Helper->messages(1476063753, 86400 * 2);
$t->get_ok(
  '/api/connection/irc-localhost/conversation/%23subtracting_months/messages?before=2016-10-31T00:02:03'
)->status_is(200)->json_is('/messages/0/message', '21 bed')
  ->json_is('/messages/59/message', '80 bead');

my %uniq;
$uniq{$_->{ts}}++ for @{$t->tx->res->json->{messages} || []};
is int(grep { $_ != 1 } values %uniq), 0,
  'add_months(-1) hack https://github.com/Nordaaker/convos/pull/292';

note 'server messages';
$connection->emit(message => $connection->messages => $_) for t::Helper->messages($t0->epoch);
$t->get_ok('/api/connection/irc-localhost/messages')->status_is(200);

note 'conversation name with slash';
$conversation = $connection->conversation({name => '#with/slash'});
$t->get_ok(
  '/api/connection/irc-localhost/conversation/%23with%2Fslash/messages.json?after=2020-01-01T00:00:00'
)->status_is(200);

note 'bad input';
$t->get_ok(
  '/api/connection/irc-localhost/conversation/%23convos/messages?before=2015-06-09T02:39:51&after=2016-06-09T02:39:58'
)->status_is(400)->json_is('/errors/0/message', 'Must be before "/after".');
$t->get_ok(
  '/api/connection/irc-localhost/conversation/%23convos/messages?after=2015-06-09T02:39:51&before=2016-06-15T02:39:58'
)->status_is(400)->json_is('/errors/0/message', 'Must be less than "/after" - 12 months.');

note 'clear';
$connection->send_p('#whatever', '/clear #convos')
  ->$wait_reject('WARNING! /clear history [name] will delete all messages in the backend!');
$connection->send_p('#whatever', '/clear history #foo')->$wait_reject('Unknown target.');
$connection->send_p('#whatever', '/clear history #convos')
  ->$wait_success('deleted convos messages');
$t->get_ok('/api/connection/irc-localhost/conversation/%23convos/messages')->status_is(200)
  ->json_is('/messages', []);

done_testing;

sub num_messages_is {
  my ($t, $exp, $desc) = @_;
  my $messages = $t->tx->res->json->{messages} || [];
  is int(@$messages), $exp, "num messages $exp - $desc";
}
