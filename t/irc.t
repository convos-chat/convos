use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user('test.user@example.com', {});
my $connection = $user->connection(irc => 'localhost', {});
my $settings_file = File::Spec->catfile($ENV{CONVOS_HOME}, qw( test.user@example.com irc localhost settings.json ));
my $err;

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'test.user@example.com', 'user.email';

ok !-e $settings_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $settings_file, 'created storage file';

is_deeply($connection->TO_JSON, {name => 'localhost', state => 'connecting', url => ''}, 'TO_JSON');

$connection->connect(sub { $err = $_[1] });
like $err, qr{Invalid URL}, 'invalid url';

is $connection->_irc->nick, 'test_user', 'converted username to nick';

$connection->url->parse('irc://127.0.0.1');
no warnings qw( once redefine );
*Mojo::IRC::connect = sub {
  my ($irc, $cb) = @_;
  $irc->$cb("SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol");
};

is $connection->url->query->param('tls'), undef, 'enable tls';
$connection->connect(sub { $err = $_[1] });
like $err, qr{\bSSL\b}, 'SSL connect attempt';
is $connection->url->query->param('tls'), 0, 'disable tls';

$connection->send('', '0', sub { $err = $_[1]; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
like $err, qr{without target and message}, 'send: without target and message';

$connection->send('#test_convos' => '0', sub { $err = $_[1]; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
like $err, qr{Not connected}i, 'send: not connected';

is $connection->user, $user, 'user';
$err = 'remove_connection cb not called';
ok -e $settings_file, 'settings_file exists before remove_connection()';
$user->remove_connection($connection->protocol, $connection->name, sub { $err = pop; Mojo::IOLoop->stop },);
Mojo::IOLoop->start;

is $err, '', 'no error on remove_connection';
is $connection->user, undef, 'user() undef';
ok !-e $settings_file, 'settings_file removed after remove_connection()';
ok !-e File::Basename::dirname($settings_file), 'all files removed';

File::Path::remove_tree($ENV{CONVOS_HOME});
done_testing;
