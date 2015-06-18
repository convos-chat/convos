use Test::Mojo::IRC -basic;
use Mojo::IOLoop;
use Convos::Core;
use Test::Deep;

my $t                = Test::Mojo::IRC->new;
my $server           = $t->start_server;
my $core             = Convos::Core->new;
my $user             = $core->user('superman@example.com', {});
my $connection       = $user->connection(IRC => 'localhost', {});
my $conversation     = $connection->conversation('#convos' => {});
my $log              = '';
my $conversation_log = '';

$connection->on(log => sub { $log .= "[$_[1]] $_[2]\n" });
$conversation->on(log => sub { $conversation_log .= join ' ', shift->id, @_ });

{
  my @err = (
    "SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol\n",
    "IO::Socket::SSL 1.94+ required for TLS support",
  );
  my $err;
  no warnings qw( once redefine );
  local *Mojo::IRC::UA::connect = sub {
    my ($irc, $cb) = @_;
    $irc->$cb(shift @err || 'Yikes!');
  };
  $connection->url->parse("irc://$server");
  while (@err) {
    $connection->url->query->remove('tls');
    $connection->connect(sub { $err = $_[1] });
    is $connection->url->query->param('tls'), 0, 'tls disabled automatically';
  }
  like $log, qr{\bSSL\s}m, 'logged ssl error';
}

$connection->_irc->emit('close');
like $log, qr{^\[info\] You \[superman\@\S+\] have quit \[Connection closed\.\]$}m, 'logged quit';
ok !$connection->{_irc}, '_irc deleted';

$connection->_irc->emit(error => 'All the things went wrong');
like $log, qr{^\[error\] All the things went wrong$}m, 'logged error';

$connection->_irc->emit(err_cannotsendtochan => {params => [undef, '#channel_name']});
like $log, qr{^\[debug\] Cannot send to channel \#channel_name\.$}m, 'logged err_cannotsendtochan';

$connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
$connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
like $log,   qr{^\[warn\] Nickname cool_nick is already in use\.$}m, 'logged err_nicknameinuse';
unlike $log, qr{\[warn\] Nickname cool_nick.*Nickname cool_nick}s,   'logged err_nicknameinuse once';

$connection->_irc->emit(err_nosuchnick => {params => [undef, '#channel_name']});
like $log, qr{^\[debug\] No such nick or channel \#channel_name.$}m, 'logged err_nosuchnick';

$connection->_irc->emit(irc_error => {params => ['Yikes!', 'All the things went wrong']});
like $log, qr{^\[error\] Yikes! All the things went wrong$}m, 'logged irc_error';

$connection->_irc->emit(irc_rpl_yourhost =>
    {params => [undef, 'Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2']});
like $log, qr{^\[info\] \QYour host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2\E$}m,
  'logged irc_rpl_yourhost';

done_testing;
