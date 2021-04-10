#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;

my $server = t::Server::Irc->new->start;
my $t      = t::Helper->t;
$t->app->core->settings->default_connection(Mojo::URL->new($server->url))->open_to_public(true);

note 'No user';
$t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
$t->get_ok('/api/users')->status_is(403)
  ->json_is('/errors/0/message', 'Only admins can list users.');

note 'First user';
$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => '1234567890'})->status_is(200)
  ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
$t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
  ->json_is('/users/1', undef);

note 'Delete / update other users as admin';
$t->delete_ok('/api/user/superduper@example.com')->status_is(200)->json_is('/message', 'Deleted.');
$t->post_ok('/api/user/superduper@example.com', json => {})->status_is(404)
  ->json_is('/errors/0/message', 'No such user.');

note 'Logout first user';
$t->get_ok('/api/user/logout')->status_is(302);

note 'Second user';
$t->post_ok('/api/user/register',
  json => {email => 'superwoman@example.com', password => '1234567890'})->status_is(200);
$t->get_ok('/api/users')->status_is(403)
  ->json_is('/errors/0/message', 'Only admins can list users.');

note 'Cannot change roles as normal user';
$t->post_ok('/api/user/superwoman@example.com', json => {roles => ['admin']})->status_is(200);
$t->get_ok('/api/user')->status_is(200)->json_is('/roles', []);

note 'Delete / update other users as normal user';
$t->delete_ok('/api/user/superman@example.com')->status_is(403)
  ->json_is('/errors/0/message', 'Only admins can delete other users.');
$t->post_ok('/api/user/superman@example.com', json => {})->status_is(403)
  ->json_is('/errors/0/message', 'Only admins can update other users.');

note 'Logout second user';
$t->get_ok('/api/user/logout')->status_is(302);
$server->client($t->app->core->get_user('superwoman@example.com')->connections->[0])
  ->server_event_ok('_irc_event_nick')->process_ok;
delete $server->{client};

note 'First user again';
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => '1234567890'})
  ->status_is(200);
$t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
  ->json_is('/users/0/roles', ['admin'])->json_is('/users/1/email', 'superwoman@example.com')
  ->json_is('/users/1/roles', [])->json_is('/users/2', undef);

note 'Can change roles as admin';
$t->post_ok('/api/user/superwoman@example.com', json => {roles => ['admin']})->status_is(200);
$t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
  ->json_is('/users/0/roles', ['admin'])->json_is('/users/1/email', 'superwoman@example.com')
  ->json_is('/users/1/roles', ['admin'])->json_is('/users/2',       undef);

note 'Delete user';
is $t->app->core->n_users, 2, 'got two users left';
is $server->n_connections, 2, 'has two connections';
$t->delete_ok('/api/user/superwoman@example.com')->status_is(200)->json_is('/message', 'Deleted.');
is $t->app->core->n_users, 1, 'only one user left';
is $server->n_connections, 1, 'only one connection left';

done_testing;
