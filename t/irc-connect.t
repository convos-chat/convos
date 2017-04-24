#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;
use Mojo::Util 'monkey_patch';

my $core = Convos::Core->new;
my $connection = $core->user({email => 'test.user@example.com'})
  ->connection({name => 'localhost', protocol => 'irc'});
my ($err, @state);

$connection->state('disconnected');
$connection->on(state => sub { push @state, $_[2]->{state} });
$connection->url->parse('irc://irc.example.com');

monkey_patch(
  'Mojo::IRC',
  connect => sub {
    pop->(
      $_[0],
      "SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol"
    );
  }
);

is $connection->url->query->param('tls'), undef, 'try tls first';
$connection->connect(sub { $err = $_[1]; Mojo::IOLoop->stop; });
is $connection->_irc->nick, 'test_user', 'converted username to nick';
is $connection->_irc->user, 'testuser',  'username can only contain a-z';

Mojo::IOLoop->start;
is_deeply \@state, [qw(queued disconnected)], 'queued => disconnected' or diag join ' ', @state;
like $err, qr{\bSSL connect attempt failed\b}, 'SSL connect failed';
is $connection->url->query->param('tls'), 0, 'disable tls';

Mojo::IOLoop->recurring(0.1 => sub { $core->_dequeue });
monkey_patch('Mojo::IRC',
  connect => sub { pop->($_[0], 'IO::Socket::SSL 1.94+ required for TLS support') });
$connection->url->query->remove('tls');
$connection->connect(sub { $err = $_[1]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
cmp_deeply([values %{$core->{connect_queue}}], [[[$connection, undef]]], 'connect_queue');
like $err, qr{\bIO::Socket::SSL\b}, 'IO::Socket::SSL missing';
is $connection->url->query->param('tls'), 0, 'disable tls';
is_deeply \@state, [qw(queued disconnected queued disconnected)], 'queued => disconnected';

monkey_patch('Mojo::IRC', connect => sub { pop->($_[0], '') });
$core->connect($connection, sub { $err = $_[1]; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
is $err, '', 'no error';
is_deeply \@state, [qw(queued disconnected queued disconnected queued connected)], 'connected';

done_testing;
