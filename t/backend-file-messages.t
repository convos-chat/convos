#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

t::Helper->subprocess_in_main_process;

my $t = t::Helper->t;
File::Path::remove_tree($t::Helper::CONVOS_HOME);
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $dialog     = $connection->dialog({name => '#convos'});

my $ts_re = qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;

note 'not logged in';
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages')->status_is(401);
$t->get_ok('/api/notifications')->status_is(401);

note 'no messages';
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages')->status_is(200)
  ->json_is('/end', true)->json_is('/messages', [])->json_is('/n_messages', 0, 'zero messages')
  ->json_is('/n_requested', 60, 'default limit');

note 'before=now';
$connection->emit(message => $dialog => $_) for t::Helper->messages(time);
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages')->status_is(200)
  ->json_is('/end', true, 'end')->json_like('/messages/0/ts', $ts_re)
  ->json_is('/messages/0/highlight', false)->json_is('/messages/0/type', 'private')
  ->json_is('/messages/0/from',      'industry')->json_is('/messages/0/message', '21 bed')
  ->json_is('/messages/59/from',     'toad')->json_is('/messages/59/message', '80 bead')
  ->json_is('/messages/60',          undef)->json_is('/n_messages', 60, 'all messages')
  ->json_is('/n_requested', 60, 'default limit');

note 'limit=1';
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?limit=1')->status_is(200)
  ->json_is('/end', true, 'end')->json_is('/messages/0/from', 'toad')
  ->json_is('/messages/0/message', '80 bead')->json_is('/messages/1', undef)
  ->json_is('/n_messages', 1, 'one message')->json_is('/n_requested', 1, 'requested 1');

my $before = Time::Piece->gmtime(time - 86400 * 180);
note "before=@{[$before->datetime]}";
$connection->emit(message => $dialog => $_)
  for t::Helper->messages($before->add_months(1)->epoch, 3600 * 11);
$t->get_ok("/api/connection/irc-localhost/dialog/%23convos/messages?before=@{[$before->datetime]}")
  ->status_is(200)->json_is('/end', true, 'end')->json_is('/messages/0/from', 'river')
  ->json_is('/messages/0/message',  '0 pencil')->json_is('/messages/15/from', 'vacation')
  ->json_is('/messages/15/message', '15 society')->json_is('/messages/16', undef)
  ->json_is('/n_messages',          16);
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?before=2018-01-01T00:39:00')
  ->status_is(200)->json_is('/end', true, 'end')->json_is('/n_messages', 0, 'zero messages');

$before = Time::Piece->gmtime(time - 1800);
note "before=@{[$before->datetime]}, limit=40";
$t->get_ok(
  "/api/connection/irc-localhost/dialog/%23convos/messages?before=@{[$before->datetime]}&limit=40")
  ->status_is(200)->json_is('/end', false, 'more')->json_is('/messages/0/from', 'lip')
  ->json_is('/messages/0/message',  '77 number')->json_is('/messages/39/from', 'loaf')
  ->json_is('/messages/39/message', '35 pot')->json_is('/n_messages', 40);

my $after = Time::Piece->gmtime(time - 86400 * 170);
note "after=@{[$after->datetime]}";
$t->get_ok("/api/connection/irc-localhost/dialog/%23convos/messages?after=@{[$after->datetime]}")
  ->status_is(200)->json_is('/end', false, 'more')->json_is('/messages/0/from', 'verse')
  ->json_is('/messages/0/message',  '38 hobbies')->json_is('/messages/59/from', 'berry')
  ->json_is('/messages/59/message', '16 playground')->json_is('/messages/60', undef)
  ->json_is('/n_messages',          60)->json_is('/n_requested', 60, 'requested 60');

note "after=@{[$after->datetime]}, limit=200";
$t->get_ok(
  "/api/connection/irc-localhost/dialog/%23convos/messages?after=@{[$after->datetime]}&limit=200")
  ->status_is(200)->json_is('/end', true, 'end')->json_is('/messages/0/from', 'verse')
  ->json_is('/messages/0/message',   '38 hobbies')->json_is('/messages/123/from', 'toad')
  ->json_is('/messages/123/message', '80 bead')->json_is('/messages/124', undef)
  ->json_is('/n_messages',           124)->json_is('/n_requested', 200, 'requested 200');

note 'match';
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?limit=1&match=playground')
  ->status_is(200)->json_is('/end', false, 'more')->json_is('/messages/0/message', '16 playground')
  ->json_is('/messages/1', undef);
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?limit=2&match=playground')
  ->status_is(200)->json_is('/end', true, 'end')->json_is('/messages/0/message', '16 playground')
  ->json_is('/messages/1/message', '16 playground');

$after  = Time::Piece->gmtime(time - 86400 * 200);
$before = Time::Piece->gmtime(time);
note "after=@{[$after->datetime]}, before=@{[$before->datetime]} (all messages)";
$t->get_ok(
  "/api/connection/irc-localhost/dialog/%23convos/messages?after=@{[$after->datetime]}&before=@{[$before->datetime]}"
)->status_is(200)->json_is('/end', true, 'end')->json_is('/messages/0/from', 'river')
  ->json_is('/messages/0/message',   '0 pencil')->json_is('/messages/161/from', 'toad')
  ->json_is('/messages/161/message', '80 bead')->json_is('/messages/162', undef)
  ->json_is('/n_messages',           162)->json_is('/n_requested', 200, 'requested 200');
$t->get_ok('/api/notifications')->status_is(200)->json_like('/messages/0/ts', $ts_re)
  ->json_is('/messages/0/connection_id', 'irc-localhost')
  ->json_is('/messages/0/dialog_id',     '#convos')->json_is('/messages/0/from', 'wall')
  ->json_is('/messages/0/type',          'notice')
  ->json_is('/messages/0/message',       '55 superman notification')
  ->json_is('/messages/1/message',       '55 superman notification')->json_is('/messages/2', undef);

note 'match=æ';
$connection->emit(
  message => $dialog => {
    from      => 'someone',
    highlight => false,
    message   => q(the character æ is unicode),
    ts        => time,
    type      => 'private',
  }
);

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?limit=1&match=æ')
  ->status_is(200)->json_is('/messages/0/message', q(the character æ is unicode));

note
  'As documented in Time::Piece, doing month math at the end of the month doesn\'t always do what you expect - @jberger';
$dialog = $connection->dialog({name => '#subtracting_months'});
$connection->emit(message => $dialog => $_) for t::Helper->messages('2016-10-28T23:40:03', 86400);
$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23subtracting_months/messages?before=2016-10-31T00:02:03')
  ->status_is(200)->json_is('/end', false)->json_is('/messages/0/message', '21 bed')
  ->json_is('/messages/59/message', '80 bead');

my %uniq;
$uniq{$_->{ts}}++ for @{$t->tx->res->json->{messages} || []};
is int(grep { $_ != 1 } values %uniq), 0,
  'add_months(-1) hack https://github.com/Nordaaker/convos/pull/292';

note 'server messages';
$connection->emit(message => $connection->messages => $_) for t::Helper->messages(time, 130);
$t->get_ok('/api/connection/irc-localhost/messages')->status_is(200)->json_is('/n_messages', 60);

note 'dialog name with slash';
$dialog = $connection->dialog({name => '#with/slash'});
$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23with%2Fslash/messages.json?after=2020-01-01T00:00:00')
  ->status_is(200)->json_is('/n_messages', 0);

note 'bad input';
$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-06-09T02:39:51&after=2016-06-09T02:39:58'
)->status_is(400)->json_is('/errors/0/message', 'Must be before "/after".');
$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?after=2015-06-09T02:39:51&before=2016-06-15T02:39:58'
)->status_is(400)->json_is('/errors/0/message', 'Must be less than "/after" - 12 months.');

note 'clear';
$connection->send_p('#whatever', '/clear #convos')
  ->$wait_reject('WARNING! /clear history [name] will delete all messages in the backend!');
$connection->send_p('#whatever', '/clear history #foo')->$wait_reject('Unknown target.');
$connection->send_p('#whatever', '/clear history #convos')
  ->$wait_success('deleted convos messages');
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages')->status_is(200)
  ->json_is('/messages', []);

done_testing;
