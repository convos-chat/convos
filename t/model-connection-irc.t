use Mojo::Base -strict;
use Convos::Model;
use Test::More;

local $ENV{CONVOS_SHARE_DIR} = 'convos-test-model-connection-irc';

my $model = Convos::Model->new;

my $user = $model->user(email => 'jhthorsen@cpan.org', avatar => 'whatever');
my $connection = $user->connection(IRC => 'localhost');
my $storage_file
  = File::Spec->catfile($ENV{CONVOS_SHARE_DIR}, 'jhthorsen@cpan.org', 'connection', 'localhost', 'irc.json');

is $connection->name, 'localhost', 'connection.name';
is $connection->user->email, 'jhthorsen@cpan.org', 'user.email';

ok !-e $storage_file, 'no storage file';
is $connection->save, $connection, 'save';
ok -e $storage_file, 'created storage file';

is_deeply($connection->TO_JSON, {name => 'localhost'}, 'TO_JSON');

File::Path::remove_tree($ENV{CONVOS_SHARE_DIR});
done_testing;
