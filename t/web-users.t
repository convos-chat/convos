#!perl
use lib '.';
use t::Helper;
use t::Server::Irc;

my $server = t::Server::Irc->new->start;
my $t      = t::Helper->t;
$t->app->core->settings->default_connection(Mojo::URL->new($server->url))->open_to_public(true);

subtest 'no user' => sub {
  $t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
  $t->get_ok('/api/users')->status_is(403)
    ->json_is('/errors/0/message', 'Only admins can list users.');
};

subtest 'first user' => sub {
  $t->post_ok('/api/user/register',
    json => {email => 'superman@example.com', password => '1234567890'})->status_is(200)
    ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
  $t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
    ->json_is('/users/1', undef);
};

subtest 'delete / update other users as admin' => sub {
  $t->delete_ok('/api/user/superduper@example.com')->status_is(200)
    ->json_is('/message', 'Deleted.');
  $t->post_ok('/api/user/superduper@example.com', json => {})->status_is(404)
    ->json_is('/errors/0/message', 'No such user.');
};

subtest 'logout first user' => sub {
  $t->get_ok('/api/user/logout')->status_is(302);
};

subtest 'second user' => sub {
  $t->post_ok('/api/user/register',
    json => {email => 'superwoman@example.com', password => '1234567890'})->status_is(200);
  $t->get_ok('/api/users')->status_is(403)
    ->json_is('/errors/0/message', 'Only admins can list users.');
};

subtest 'cannot change roles as normal user' => sub {
  $t->post_ok('/api/user/superwoman@example.com', json => {roles => ['admin']})->status_is(200);
  $t->get_ok('/api/user')->status_is(200)->json_is('/roles', []);
};

subtest 'delete / update other users as normal user' => sub {
  $t->delete_ok('/api/user/superman@example.com')->status_is(403)
    ->json_is('/errors/0/message', 'Only admins can delete other users.');
  $t->post_ok('/api/user/superman@example.com', json => {})->status_is(403)
    ->json_is('/errors/0/message', 'Only admins can update other users.');
};

subtest 'logout second user' => sub {
  $t->get_ok('/api/user/logout')->status_is(302);
  $server->client($t->app->core->get_user('superwoman@example.com')->connections->[0])
    ->server_event_ok('_irc_event_nick')->process_ok;
  delete $server->{client};
};

subtest 'first user again' => sub {
  $t->post_ok('/api/user/login',
    json => {email => 'superman@example.com', password => '1234567890'})->status_is(200);
  $t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
    ->json_is('/users/0/roles', ['admin'])->json_is('/users/1/email', 'superwoman@example.com')
    ->json_is('/users/1/roles', [])->json_is('/users/2', undef);
};

subtest 'can change roles as admin' => sub {
  $t->post_ok('/api/user/superwoman@example.com', json => {roles => ['admin']})->status_is(200);
  $t->get_ok('/api/users')->status_is(200)->json_is('/users/0/email', 'superman@example.com')
    ->json_is('/users/0/roles', ['admin'])->json_is('/users/1/email', 'superwoman@example.com')
    ->json_is('/users/1/roles', ['admin'])->json_is('/users/2',       undef);
};

subtest 'delete user' => sub {
  is $t->app->core->n_users, 2, 'got two users left';
  is $server->n_connections, 2, 'has two connections';
  $t->delete_ok('/api/user/superwoman@example.com')->status_is(200)
    ->json_is('/message', 'Deleted.');
  is $t->app->core->n_users, 1, 'only one user left';
  is $server->n_connections, 1, 'only one connection left';
};

done_testing;
