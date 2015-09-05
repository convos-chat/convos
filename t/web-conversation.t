use t::Helper;
no warnings 'redefine';

my $t = t::Helper->t;
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->post_ok('/1.0/connection/irc/localhost/conversation/%23convos')->status_is(401);
$t->post_ok('/1.0/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);

$t->post_ok('/1.0/connection/irc/localhost/conversation/%23convos')->status_is(400)
  ->json_is('/errors/0/message', 'Not connected');

$user->connection(irc => 'localhost', {})->join_conversation('#private', sub { })->state('connected');
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };
$t->post_ok('/1.0/connection/irc/localhost/conversation/%23convos')->status_is(200)->json_is('/frozen', '')
  ->json_is('/id', '#convos')->json_is('/name', '#convos')->json_is('/topic', '')->json_is('/users', {});

done_testing;
