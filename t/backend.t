use t::Helper;
use Convos::Core::Backend;

my $backend = Convos::Core::Backend->new;
my $user = bless {};
my ($connections, $err, $users);

is $backend->find_connections($user, sub { ($err, $connections) = @_[1, 2] }), $backend, 'find_connections';
is_deeply $connections, [], 'no connections';

is $backend->find_users(sub { ($err, $users) = @_[1, 2] }), $backend, 'find_users';
is_deeply $users, [], 'no connections';

is $backend->load_object($user), $backend, 'load_object sync';
is $backend->load_object($user, sub { $err = "load_object @_" }), $backend, 'load_object async';
like $err, qr{load_object main}, 'object loaded';

is $backend->save_object($user), $backend, 'save_object sync';
is $backend->save_object($user, sub { $err = "save_object @_" }), $backend, 'save_object async';
like $err, qr{save_object main}, 'object saved';

my $messages;
is $backend->messages({}, sub { $messages = $_[2]; }), $backend, 'messages async';
is_deeply $messages, [], 'messages';

done_testing;
