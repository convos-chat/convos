use t::Helper;

my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret')->save;

$t->post_ok('/api/connection/irc-localhost/dialogs', json => {name => '#convos'})->status_is(401);
$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);

$t->post_ok('/api/connection/irc-localhost/dialogs', json => {name => "#c"})->status_is(400)
  ->json_has('/errors/0/message');

$user->connection({name => 'localhost', protocol => 'irc'})->join_dialog('#private', sub { })
  ->state('connected');
$t->post_ok('/api/connection/irc-localhost/dialogs', json => {name => '#convos'})->status_is(400)
  ->json_is('/errors/0/message', 'Not connected.');

no warnings qw(once redefine);
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };
$t->post_ok('/api/connection/irc-localhost/dialogs', json => {name => '#convos'})->status_is(200)
  ->json_is('/frozen', '')->json_is('/id', '#convos')->json_is('/name', '#convos')
  ->json_is('/topic', '')->json_is('/users', {});

done_testing;
