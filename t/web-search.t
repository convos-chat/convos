#!perl
use lib '.';
use t::Helper;

my $t    = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');
$user->save_p->$wait_success('save_p');

note 'not logged in';
$t->get_ok('/api/search')->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

note 'empty result';
$t->get_ok('/api/search')->status_is(200)->json_is('/end', true)->json_is('/messages', []);
$t->get_ok('/api/search?match=xyz')->status_is(200)->json_is('/end', true)
  ->json_is('/messages', []);

note 'search everything';
my $connection   = $user->connection({url => 'irc://localhost'});
my $conversation = $connection->conversation({name => '#convos'});
$t->get_ok('/api/search?match=xyz')->status_is(200)->json_is('/end', false)
  ->json_is('/messages', []);

$connection->emit(message => $conversation => $_) for t::Helper->messages(time - 3600);
$t->get_ok('/api/search?match=secretary')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'shade')->json_is('/messages/0/message', '52 secretary');

note "match whole word";
$t->get_ok('/api/search?match="secretary"')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'shade')->json_is('/messages/0/message', '52 secretary');
$t->get_ok('/api/search?match="secret"')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0', undef);

note "match from channel";
$t->get_ok('/api/search?match=sec%20%23convos')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'insect')->json_is('/messages/1/from', 'shade')
  ->json_is('/messages/2',      undef);
$t->get_ok('/api/search?match=sec%20%23foo')->status_is(200)->json_is('/end', true)
  ->json_is('/messages/0', undef);

note "match from nick";
$t->get_ok('/api/search?match=sec%20%40INSECT')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'insect')->json_is('/messages/1', undef);
$t->get_ok('/api/search?match=%40insect')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'insect')->json_is('/messages/1', undef);
$t->get_ok('/api/search?match=sec%20%40ins')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0', undef);

$t->get_ok('/api/search?from=profit&match=6')->status_is(200)->json_is('/end', false)
  ->json_is('/messages/0/from', 'profit')->json_is('/messages/0/message', '62 toys')
  ->json_is('/messages/1/from', 'profit')->json_is('/messages/1/message', '65 canvas')
  ->json_is('/messages/2',      undef);

done_testing;
