use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

$ENV{CONVOS_HOME} = File::Spec->catdir(qw( t data convos-test-backend-file-messages ));

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user('superman@example.com', {});
my $connection = $user->connection(irc => 'localhost', {});
my $conversation = $connection->conversation('#convos'), my ($err, $messages);

$conversation->messages({}, sub { ($err, $messages) = @_[1, 2]; });
is int @$messages, 60, 'got max limit messages';
is $messages->[0]{timestamp},  '2015-06-21T14:12:17', 'first: 2015-06-21T14:12:17';
is $messages->[-1]{timestamp}, '2015-06-22T10:23:50', 'last: 2015-06-22T10:23:50';

$conversation->messages({level => 'warn|error'}, sub { ($err, $messages) = @_[1, 2]; });
is int @$messages, 3, 'got two warn,error messages';
is $messages->[0]{timestamp},  '2015-06-21T10:12:25', 'first: 2015-06-21T10:12:25';
is $messages->[-1]{timestamp}, '2015-06-22T09:12:21', 'first: 2015-06-22T09:12:21';

$conversation->messages({level => 'info', match => 'iotop'}, sub { ($err, $messages) = @_[1, 2]; });
is int @$messages, 1, 'one message matching iotop';
is $messages->[0]{timestamp}, '2015-06-21T10:13:32', 'first: 2015-06-21T10:13:32';

$conversation->messages({limit => 2, match => qr{\bpacka\w+\b}}, sub { ($err, $messages) = @_[1, 2]; });
is int @$messages, 2, 'two messages matching package';
is $messages->[0]{timestamp}, '2015-06-22T10:13:29', 'first: 2015-06-22T10:13:29';

done_testing;
