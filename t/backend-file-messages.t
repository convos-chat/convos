use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

$ENV{CONVOS_HOME} = File::Spec->catdir(qw(t data convos-test-backend-file-messages));

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $dialog = $connection->dialog({name => '#convos'});
my ($err, $messages);

$dialog->messages({}, sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 0, 'no messages in the past year' or diag $err;

$dialog->messages({before => "2014-06-30T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 60, 'before: got max limit messages' or diag $err;
is $messages->[0]{ts},  '2014-06-21T14:12:17', 'first: 2014-06-21T14:12:17';
is $messages->[-1]{ts}, '2014-06-22T10:23:50', 'last: 2014-06-22T10:23:50';

$dialog->messages({before => "2014-06-21T14:30:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 41, 'before: middle of the log' or diag $err;
is $messages->[0]{ts},  '2014-06-21T10:12:20', 'first: 2014-06-21T10:12:20';
is $messages->[-1]{ts}, '2014-06-21T14:17:40', 'last: 2014-06-21T14:17:40';

$dialog->messages({after => "2014-06-30T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 60, 'after: got max limit messages' or diag $err;
is $messages->[0]{ts},  '2014-08-21T14:12:17', 'first: 2014-08-21T14:12:17';
is $messages->[-1]{ts}, '2014-08-22T10:23:50', 'last: 2014-08-22T10:23:50';

$dialog->messages({after => "2014-06-21T14:30:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 60, 'after: middle of the log' or diag $err;
is $messages->[0]{ts},  '2014-08-21T14:12:17', 'first: 2014-08-21T14:12:17';
is $messages->[-1]{ts}, '2014-08-22T10:23:50', 'last: 2014-08-22T10:23:50';

$dialog->messages({after => "2014-06-21T14:30:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is int @$messages, 60, 'span multiple log files to get max messages' or diag $err;
is $messages->[0]{ts},  '2014-08-21T14:12:17', 'first: 2014-08-21T14:12:17';
is $messages->[-1]{ts}, '2014-08-22T10:23:50', 'last: 2014-08-22T10:23:50';

$dialog->messages(
  {before => "2014-04-01T00:00:00", after => "2014-04-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 0, 'before and after: same' or diag $err;

$dialog->messages(
  {before => "2014-04-01T00:00:00", after => "2015-04-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 0, 'before and after: "after" after "before"' or diag $err;

$dialog->messages(
  {before => "2015-04-01T00:00:00", after => "2013-04-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 0, 'before and after: difference > 12 months' or diag $err;

$dialog->messages(
  {before => "2013-04-01T00:00:00", after => "2015-04-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 0, 'before and after: difference > 12 months (2)' or diag $err;

$dialog->messages(
  {match => 'iotop', after => "2014-08-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 2, 'two messages matching iotop' or diag $err;
is $messages->[0]{ts}, '2014-08-21T10:13:32', 'first: 2014-08-21T10:13:32';

$dialog->messages(
  {limit => 2, match => qr{\bpacka\w+\b}, after => "2014-08-01T00:00:00"},
  sub { ($err, $messages) = @_[1, 2]; Mojo::IOLoop->stop; }
);
Mojo::IOLoop->start;
is int @$messages, 2, 'two messages matching package because of limit' or diag $err;
is $messages->[0]{ts}, '2014-08-22T10:13:29', 'first: 2014-08-22T10:13:29';

done_testing;
