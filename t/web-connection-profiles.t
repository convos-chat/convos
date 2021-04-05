#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->delete_ok('/api/connection-profiles/irc-freenode')->status_is(401);
$t->get_ok('/api/connection-profiles')->status_is(401);
$t->post_ok('/api/connection-profiles', json => {url => 'irc://localhost'})->status_is(401);

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->get_ok('/api/connection-profiles')->status_is(200)->json_is(
  '/profiles',
  [{
    id                    => 'irc-freenode',
    is_default            => true,
    is_forced             => false,
    max_bulk_message_size => 3,
    max_message_length    => 512,
    service_accounts      => [qw(chanserv nickserv)],
    skip_queue            => false,
    url                   => 'irc://chat.freenode.net:6697/%23convos',

    # webirc_password       => '', <--- not admin
  }]
);

$t->delete_ok('/api/connection-profiles/irc-freenode')->status_is(403)
  ->json_is('/errors/0/message', 'Only admins can delete connection profiles.');

$user->role(give => 'admin');
$t->delete_ok('/api/connection-profiles/irc-freenode')->status_is(400)
  ->json_is('/errors/0/message', 'You cannot delete the default connection.');

$t->post_ok('/api/connection-profiles', json => {url => 'irc://localhost'})->status_is(200)
  ->json_is('/id', 'irc-localhost');

my %profile = (
  id                    => 'foo',                              # ignored
  is_default            => true,                               # change default_connection
  is_forced             => true,                               # change forced_connection
  url                   => 'irc://localhost:6697/%23convos',
  max_message_length    => 99,
  max_bulk_message_size => 32,
  service_accounts      => ['fooserv'],
  skip_queue            => true,
  webirc_password       => 'yikes',
);
$t->post_ok('/api/connection-profiles', json => \%profile)->status_is(200)
  ->json_is('', {%profile, id => 'irc-localhost'});

$t->get_ok('/api/user')->status_is(200)->json_is('/default_connection', $profile{url});

$t->get_ok('/api/connection-profiles')->status_is(200)->json_is('/profiles/0/id', 'irc-freenode')
  ->json_is('/profiles/1/id', 'irc-localhost');

$t->delete_ok('/api/connection-profiles/irc-freenode')->status_is(200)
  ->json_is('/message', 'Deleted.');

$t->delete_ok('/api/connection-profiles/irc-freenode')->status_is(200, 'already deleted')
  ->json_is('/message', 'Deleted.');

done_testing;
