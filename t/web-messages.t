use t::Helper;

$ENV{CONVOS_HOME} = File::Spec->catdir(qw( t data convos-test-backend-file-messages ));

my $t = t::Helper->t;
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->get_ok('/1.0/connection/irc/localhost/conversation/%23convos/messages')->status_is(401);
$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);

$t->get_ok('/1.0/connection/irc/localhost/conversation/%23convos/messages')->status_is(200);
is int @{$t->tx->res->json->{messages}}, 60, 'got max limit messages';

$t->get_ok('/1.0/connection/irc/localhost/conversation/%23convos/messages?limit=1')->status_is(200)
  ->json_is('/messages/0/level',   'info')
  ->json_is('/messages/0/message', 'The powernap package allows you to suspend servers which are not being used,')
  ->json_is('/messages/0/sender',  'mr22')->json_is('/messages/0/timestamp', '2015-06-22T10:23:50')
  ->json_is('/messages/0/type',    'privmsg')->json_is('/messages/1', undef);

$t->get_ok('/1.0/connection/irc/localhost/conversation/%23convos/messages?limit=3&match=AppArmor&level=warn')
  ->status_is(200)->json_is('/messages/0/level', 'warn')
  ->json_is('/messages/0/message', 'Unsure if AppArmor might be causing an issue? Don\'t disable it, use the')
  ->json_is('/messages/0/sender',  'jhthorsen')->json_is('/messages/0/timestamp', '2015-06-21T10:12:25')
  ->json_is('/messages/0/type',    'privmsg')->json_is('/messages/1', undef);

done_testing;
