#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

t::Helper->subprocess_in_main_process;

my $t    = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $dialog     = $connection->dialog({name => '#convos'});

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages')->status_is(401);
$t->get_ok('/api/notifications')->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-06-09T08:39:00.123Z')
  ->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 0, 'no messages';

$connection->emit(message => $dialog => $_) for t::Helper->messages;
$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-06-09T08:39:00')
  ->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 60, 'got max limit messages';

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-06-09T08:39:00&limit=1')
  ->status_is(200)->json_is(
  '/messages',
  [{
    highlight => false,
    message   => '[convos] jhthorsen pushed 1 new commit to master: https://git.io/vDF6H',
    from      => 'mr22',
    ts        => '2015-06-09T02:41:42',
    type      => 'private',
  }]
  );

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?before=2015-06-09T04:37:00&limit=2&match=AppArmor'
)->status_is(200)->json_is(
  '/messages',
  [{
    highlight => false,
    message   => 'Unsure if AppArmor might be causing an issue? Don\'t disable it, use the',
    from      => 'jhthorsen',
    ts        => '2015-06-09T02:39:12',
    type      => 'private'
  }]
);

$t->get_ok('/api/connection/irc-localhost/dialog/%23convos/messages?after=2015-06-09T02:39:51.000Z')
  ->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 56, 'after';

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?after=2015-06-09T02:39:51&before=2015-06-09T02:39:58'
)->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 3, 'after and before';


$t->get_ok('/api/notifications')->status_is(200)->json_is(
  '/messages',
  [{
    connection_id => 'irc-localhost',
    dialog_id     => '#convos',
    from          => 'Supergirl',
    message       => 'An easy way to see what SUPERMAN own',
    ts            => '2015-06-09T02:39:36',
    type          => 'private'
  }]
);

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

$dialog = $connection->dialog({name => '#subtracting_months'});
$connection->emit(message => $dialog => $_) for t::Helper->messages('2016-10-30T23:40:03', 130);
$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23subtracting_months/messages?before=2016-10-31T00:02:03')
  ->status_is(200);

my %uniq;
$uniq{$_->{ts}}++ for @{$t->tx->res->json->{messages} || []};
is int(grep { $_ != 1 } values %uniq), 0,
  'add_months(-1) hack https://github.com/Nordaaker/convos/pull/292';

$connection->emit(message => $connection->messages => $_) for t::Helper->messages(time - 3600, 130);
$t->get_ok('/api/connection/irc-localhost/messages')->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 28, 'server messages';

$dialog = $connection->dialog({name => '#with/slash'});
$t->get_ok('/api/connection/irc-localhost/dialog/%23with%2Fslash/messages.json')->status_is(200);

$t->get_ok(
  '/api/connection/irc-localhost/dialog/%23convos/messages?after=2015-06-09T02:39:51&before=2016-06-09T02:39:58'
)->status_is(200);
is int @{$t->tx->res->json->{messages} || []}, 0, 'after and before greater than 12 months';

done_testing;
