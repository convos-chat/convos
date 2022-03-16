#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_PLUGINS} = 'Convos::Plugin::Auth::Header';
$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
$ENV{CONVOS_ADMIN}   = 'admin@convos.chat';

my $t = t::Helper->t;

subtest 'not authorized' => sub {
  $t->get_ok('/api/user')->status_is(401);
  $t->post_ok('/api/user/login',
    json => {email => 'superwoman@example.com', password => 'superduper'})->status_is(400);
};

subtest 'admin is required' => sub {
  my %headers = ('X-Authenticated-User' => 'superman@example.com');
  $t->get_ok('/api/user', \%headers)->status_is(401);

  $headers{'X-Authenticated-User'} = $ENV{CONVOS_ADMIN};
  $t->get_ok('/api/user', \%headers)->status_is(200);

  $headers{'X-Authenticated-User'} = 'superman@example.com';
  $t->get_ok('/api/user', \%headers)->status_is(200);

  $headers{'X-Authenticated-User'} = $ENV{CONVOS_ADMIN};
  $t->websocket_ok('/events')
    ->message_ok->json_message_is('/errors/0/message', 'Need to log in first.');
  $t->websocket_ok('/events', \%headers)
    ->send_ok({json => {method => 'load', object => 'user', params => {}}})
    ->message_ok->json_message_is('/user/email', $ENV{CONVOS_ADMIN});
  $t->finish_ok;
};

subtest 'unable to register or login' => sub {
  $t->post_ok('/api/user/register',
    json => {email => 'superwoman@example.com', password => 'longenough'})->status_is(401);

  $t->post_ok('/api/user/register',
    json => {email => 'superman@example.com', password => 'longenough'})->status_is(401);

  $t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => ''})
    ->status_is(400);

  $t->post_ok('/api/user/login',
    json => {email => 'superman@example.com', password => 'no_password_in_storage'})
    ->status_is(400);
};

subtest 'login enabled after changing password' => sub {
  $t->post_ok('/api/user/superman@example.com', json => {password => 'cool_beans_123'})
    ->status_is(401);

  my %headers = ('X-Authenticated-User' => 'superman@example.com');
  $t->post_ok('/api/user/superman@example.com', \%headers, json => {password => 'cool_beans_123'})
    ->status_is(200);

  $t->post_ok('/api/user/login',
    json => {email => 'superman@example.com', password => 'cool_beans_123'})->status_is(200);
};

done_testing;
