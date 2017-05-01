#!perl
use lib '.';
use t::Helper;
use Convos::Core::Backend;

my $backend = Convos::Core::Backend->new;
my $user = bless {};
my ($connections, $err, $users);

is $backend->connections($user, sub { ($err, $connections) = @_[1, 2] }), $backend, 'connections';
is_deeply $connections,          [], 'no connections';
is_deeply $backend->connections, [], 'sync connections';

is $backend->users(sub { ($err, $users) = @_[1, 2] }), $backend, 'users';
is_deeply $users,          [], 'no connections';
is_deeply $backend->users, [], 'sync users';

is $backend->save_object($user), $backend, 'save_object sync';
is $backend->save_object($user, sub { $err = "save_object @_" }), $backend, 'save_object async';
like $err, qr{save_object main}, 'object saved';

my $message;
is $backend->messages({}, {}, sub { $message = undef; }), $backend, 'messages async';
is $message, undef, 'end of messages';

done_testing;
