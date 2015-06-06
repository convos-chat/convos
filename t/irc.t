use Mojo::Base -strict;
use Convos::Core;
use Convos::Core::Backend::File;
use Test::More;

local $ENV{CONVOS_HOME} = 'convos-test-irc';

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user('test.user@example.com', {});
my $connection = $user->connection(IRC => 'localhost');
my $storage_file = File::Spec->catfile($ENV{CONVOS_HOME}, 'test.user@example.com', 'IRC-localhost', 'settings.json');
my $err;

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'test.user@example.com', 'user.email';

ok !-e $storage_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $storage_file, 'created storage file';

is_deeply($connection->TO_JSON, {name => 'localhost', rooms => [], state => 'connecting', url => ''}, 'TO_JSON');

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

$connection->send('', '0', sub { $err = $_[1] });
like $err, qr{without target and message}, 'send: without target and message';

$connection->send('#test_convos' => '0', sub { $err = $_[1] });
like $err, qr{Not connected}i, 'send: not connected';

my ($s, $m, $h, $day, $month, $year) = gmtime;
my $date = sprintf '%04d-%02d-%02d', $year + 1900, $month + 1, $day;
my $log_file = File::Spec->catfile($ENV{CONVOS_HOME}, 'test.user@example.com', 'IRC-localhost', "$date.log");
ok -e $log_file, $log_file;

File::Path::remove_tree($ENV{CONVOS_HOME});
done_testing;
