#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';

my $t = t::Helper->t;
my $registered;
subtest 'wait for backend' => sub {
  $t->app->core->settings->default_connection(Mojo::URL->new('irc://localhost:6123/%23convos'))
    ->open_to_public(true);
  is $t->app->core->ready, 1, 'ready';
};

subtest 'not logged in' => sub {
  $t->get_ok('/api/user')->status_is(401)->json_is('/errors/0/message', 'Need to log in first.');
  $t->delete_ok('/api/user/superman@example.com')->status_is(401)
    ->json_is('/errors/0/message', 'Need to log in first.');
  $t->post_ok('/api/user/superman@example.com', json => {})->status_is(401)
    ->json_is('/errors/0/message', 'Need to log in first.')->json_is('/errors/0/path', '/');
};

subtest 'register' => sub {
  $t->post_ok('/api/user/register',
    json => {email => 'superman@example.com', password => '  longenough '})->status_is(200)
    ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);
  $registered = $t->tx->res->json->{registered};
};

subtest 'update' => sub {
  $t->post_ok('/api/user/superman@example.com', json => {})->status_is(200);

  $t->get_ok('/api/user')->status_is(200);
  is_deeply(
    $t->tx->res->json,
    {
      email              => 'superman@example.com',
      forced_connection  => false,
      default_connection => 'irc://localhost:6123/%23convos',
      highlight_keywords => [],
      registered         => $registered,
      remote_address     => '127.0.0.1',
      roles              => ['admin'],
      uid                => 1,
      unread             => 0,
      video_service      => 'https://meet.jit.si/',
    },
    'user object'
  );

  $t->post_ok('/api/user/superman@example.com',
    json => {highlight_keywords => [' ', '-', '.', '  ,', '    ', 'foo ']})->status_is(200);
  $t->get_ok('/api/user')->status_is(200)->json_is('/email', 'superman@example.com')
    ->json_is('/highlight_keywords', ['foo']);
};

subtest 'update password, including unicode' => sub {
  $t->post_ok('/api/user/superman@example.com', json => {password => 'cool_beans_123'})
    ->status_is(200);
  $t->t::Helper::with_csrf('/logout')->status_is(302);
  $t->post_ok('/api/user/login',
    json => {email => 'superman@example.com', password => 'cool_beans_123'})->status_is(200);
  $t->post_ok('/api/user/superman@example.com', json => {password => '“12345678”'})->status_is(200);
  $t->t::Helper::with_csrf('/logout')->status_is(302);
  $t->post_ok('/api/user/login',
    json => {email => 'superman@example.com', password => '“12345678”'})->status_is(200);
};

subtest 'unread messages' => sub {
  my $user = $t->app->core->get_user('superman@example.com');
  $user->connection({connection_id => 'irc-localhost'})->conversation({name => '#convos'})
    ->unread(42);

  $t->get_ok('/api/user?connections=true&conversations=true')->status_is(200);
  cmp_deeply(
    $t->tx->res->json,
    superhashof({
      email         => 'superman@example.com',
      conversations => [{
        connection_id   => 'irc-localhost',
        conversation_id => '#convos',
        frozen          => 'Not connected.',
        name            => '#convos',
        notifications   => 0,
        topic           => '',
        unread          => 42,
      }],
      connections => [{
        connection_id => 'irc-localhost',
        info          => {
          authenticated => false,
          capabilities  => {},
          certificate   => {fingerprint => re(qr{^[0-9a-f]{128}$})},
          nick          => 'superman',
          socket        => ignore
        },
        name                => 'localhost',
        on_connect_commands => [],
        service_accounts    => [qw(chanserv nickserv)],
        state               => re(qr{connecting|disconnected|queued}),
        url                 => 'irc://localhost:6123/%23convos?nick=superman&tls=1',
        wanted_state        => 'connected',
      }],
    }),
    'user.json'
  );

  $t->post_ok('/api/notifications/read')->status_is(200);
};

subtest 'delete account' => sub {
  $t->delete_ok('/api/user/superman@example.com')->status_is(400)
    ->json_is('/errors/0/message', 'You are the only user left.');

  $t->t::Helper::with_csrf('/logout')->status_is(302);
  $t->get_ok('/api/user')->status_is(401);
};

subtest 'backend not ready' => sub {
  $t->app->core->ready(0);
  $t->get_ok('/api/user')->status_is(503)->json_is('/errors/0/message', 'Backend is starting.');

  $t->get_ok('/chat')->status_is(503)->element_exists('a.btn[href="/"]')
    ->text_is('a.btn[href="/"]', 'Try again')
    ->text_is('title',           'Backend is starting (503) - Convos')
    ->text_is('h1',              'Backend is starting (503)');
};

done_testing;
