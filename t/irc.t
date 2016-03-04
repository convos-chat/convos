use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user({email => 'test.user@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc', url => 'irc://127.0.0.1'});
my $settings_file = File::Spec->catfile($ENV{CONVOS_HOME}, qw( test.user@example.com irc-localhost connection.json ));
my $err;

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'test.user@example.com', 'user.email';

ok !-e $settings_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $settings_file, 'created storage file';

cmp_deeply($connection->TO_JSON,
  {id => ignore(), name => 'localhost', protocol => 'irc', state => 'connecting', url => 'irc://127.0.0.1'}, 'TO_JSON');

$connection->send('', 'whatever', sub { $err = $_[1]; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
like $err, qr{without target}, 'send: without target';

$connection->send('#test_convos' => '0', sub { $err = $_[1]; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
like $err, qr{Not connected}i, 'send: not connected';

is $connection->user, $user, 'user';
$err = 'remove_connection cb not called';
ok -e $settings_file, 'settings_file exists before remove_connection()';
$user->remove_connection($connection->id, sub { $err = pop; Mojo::IOLoop->stop },);
Mojo::IOLoop->start;

is $err, '', 'no error on remove_connection';
ok !-e $settings_file, 'settings_file removed after remove_connection()';
ok !-e File::Basename::dirname($settings_file), 'all files removed';

done_testing;
