use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;
my $user = $t->app->core->user('superman@example.com', {avatar => 'avatar@example.com'})->set_password('s3cret');

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})->status_is(200);
$t->get_ok('/api/conversations')->status_is(200)->json_is('/conversations', []);

no warnings 'redefine';
require Mojo::IRC::UA;
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };

# order does not matter
$user->connection({name => 'localhost', protocol => 'irc'})->join_conversation('#private', sub { });
$user->connection({name => 'perl-org',  protocol => 'irc'})->join_conversation('#oslo.pm', sub { });
$user->connection('irc-localhost')->join_conversation('#Convos s3cret', sub { });

$t->get_ok('/api/conversations')->status_is(200)->json_is(
  '/conversations/0',
  {
    active        => 1,
    connection_id => 'irc-localhost',
    topic         => '',
    frozen        => '',
    name          => '#Convos',
    id            => '#convos',
    users         => {}
  }
  )->json_is(
  '/conversations/1',
  {
    active        => 1,
    connection_id => 'irc-localhost',
    topic         => '',
    frozen        => '',
    name          => '#private',
    id            => '#private',
    users         => {}
  }
  )->json_is(
  '/conversations/2',
  {
    active        => 1,
    connection_id => 'irc-perl-org',
    topic         => '',
    frozen        => '',
    name          => '#oslo.pm',
    id            => '#oslo.pm',
    users         => {}
  }
  );

done_testing;
