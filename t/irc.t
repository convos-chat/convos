use Mojo::Base -strict;
use Convos::Core;
use Test::More;

local $ENV{CONVOS_SHARE_DIR} = 'convos-test-irc';

my $core       = Convos::Core->new_with_backend('File');
my $user       = $core->user('jan.henning.thorsen@example.com');
my $connection = $user->connection(IRC => 'localhost');
my $storage_file
  = File::Spec->catfile($ENV{CONVOS_SHARE_DIR}, 'jan.henning.thorsen@example.com', 'IRC-localhost', 'settings.json');
my $err;

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'jan.henning.thorsen@example.com', 'user.email';

ok !-e $storage_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $storage_file, 'created storage file';

is_deeply($connection->TO_JSON, {name => 'localhost', rooms => [], state => 'connecting', url => ''}, 'TO_JSON');

$connection->connect(sub { $err = $_[1] });
like $err, qr{Invalid URL}, 'invalid url';

is $connection->_irc->nick, 'jan_henning_thorsen', 'converted username to nick';

$connection->url->parse('irc://127.0.0.1');
no warnings qw( once redefine );
*Mojo::IRC::connect = sub {
  my ($irc, $cb) = @_;
  $irc->$cb("SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol");
};

is $connection->{disable_tls}, undef, 'enable tls';
$connection->connect(sub { $err = $_[1] });
is $err, '127.0.0.1 does not support SSL/TLS.', 'SSL connect attempt';
is $connection->{disable_tls}, 1, 'disable tls';

$connection->send('', '0', sub { $err = $_[1] });
like $err, qr{without target and message}, 'send: without target and message';

$connection->send('#test_convos' => '0', sub { $err = $_[1] });
like $err, qr{Not connected}i, 'send: not connected';

File::Path::remove_tree($ENV{CONVOS_SHARE_DIR});
done_testing;
