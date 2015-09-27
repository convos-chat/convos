use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user('test.user@example.com', {});
my $connection = $user->connection(irc => 'localhost', {url => 'irc://127.0.0.1'});
my $settings_file = File::Spec->catfile($ENV{CONVOS_HOME}, qw( test.user@example.com irc localhost settings.json ));
my $err;

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'test.user@example.com', 'user.email';

ok !-e $settings_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $settings_file, 'created storage file';

is_deeply($connection->TO_JSON, {name => 'localhost', state => 'connecting', url => 'irc://127.0.0.1'}, 'TO_JSON');

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

done_testing;
