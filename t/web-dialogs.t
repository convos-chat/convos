use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;
my $user = $t->app->core->user({email => 'superman@example.com'})->set_password('s3cret');

$t->post_ok('/api/user/login', json => {email => 'superman@example.com', password => 's3cret'})
  ->status_is(200);
$t->get_ok('/api/dialogs')->status_is(200)->json_is('/dialogs', []);

require Mojo::IRC::UA;
no warnings qw(once redefine);
*Mojo::IRC::UA::join_channel = sub { my ($irc, $channel, $cb) = @_; $irc->$cb('') };

# order does not matter
$user->connection({name => 'localhost', protocol => 'irc'})->join_dialog('#private', sub { });
$user->connection({name => 'perl-org',  protocol => 'irc'})->join_dialog('#oslo.pm', sub { });
$user->get_connection('irc-localhost')->join_dialog('#Convos s3cret', sub { });

$t->get_ok('/api/dialogs')->status_is(200)->json_is(
  '/dialogs/0',
  {
    active        => 1,
    connection_id => 'irc-localhost',
    topic         => '',
    frozen        => '',
    name          => '#Convos',
    id            => '#convos',
    is_private    => 0,
    n_users       => 0,
    users         => {}
  }
  )->json_is(
  '/dialogs/1',
  {
    active        => 1,
    connection_id => 'irc-localhost',
    topic         => '',
    frozen        => '',
    name          => '#private',
    id            => '#private',
    is_private    => 0,
    n_users       => 0,
    users         => {}
  }
  )->json_is(
  '/dialogs/2',
  {
    active        => 1,
    connection_id => 'irc-perl-org',
    topic         => '',
    frozen        => '',
    name          => '#oslo.pm',
    id            => '#oslo.pm',
    is_private    => 0,
    n_users       => 0,
    users         => {}
  }
  );

done_testing;
