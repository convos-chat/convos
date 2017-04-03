use lib '.';
use t::Helper;
use Convos::Core::Backend::File;
use Convos::Core::User;

my $backend = Convos::Core::Backend::File->new(home => Mojo::File->new($ENV{CONVOS_HOME}));
my $user = Convos::Core::User->new(email => 'jhthorsen@cpan.org');
my ($connections, $err, $users);

$err = 'invalid';
is $backend->users(sub { ($err, $users) = @_[1, 2] }), $backend, 'users';
Mojo::IOLoop->start;
is $err, '', 'no err for users';
is_deeply $users,          [], 'no users';
is_deeply $backend->users, [], 'sync users';

is $backend->save_object($user), $backend, 'save_object sync';

$err = 'invalid';
is $backend->connections($user, sub { ($err, $connections) = @_[1, 2]; Mojo::IOLoop->stop; }),
  $backend, 'connections';
Mojo::IOLoop->start;
is $err, '', 'no err for connections';
is_deeply $connections, [], 'no connections';

is_deeply $backend->connections($user), [], 'sync connections';

$err = 'invalid';
is $backend->save_object($user, sub { $err = $_[1]; Mojo::IOLoop->stop; }), $backend,
  'save_object async';
Mojo::IOLoop->start;
is $err, '', 'no err for save_object';

$err = 'invalid';
is $backend->delete_object($user, sub { ($err) = @_[1, 2]; Mojo::IOLoop->stop; }), $backend,
  'save_object async';
Mojo::IOLoop->start;
is $err, '', 'no err for delete_object';

done_testing;
