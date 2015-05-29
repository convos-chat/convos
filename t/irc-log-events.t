use Test::Mojo::IRC -basic;
use Mojo::IOLoop;
use Convos::Model;
use Test::Deep;

my $t      = Test::Mojo::IRC->new;
my $server = $t->start_server;

local $ENV{CONVOS_SHARE_DIR} = '/dev/null';    # test should not need share dir

my $model      = Convos::Model->new;
my $user       = $model->user(email => 'superman@example.com', avatar => 'whatever');
my $connection = $user->connection(IRC => $server);

no warnings qw( once redefine );
open my $LOG_FH, '>', \my $log;
Mojo::Util::monkey_patch(ref($connection), _log_fh => sub {$LOG_FH});

{
  my $err;
  local *Mojo::IRC::UA::connect = sub {
    my ($irc, $cb) = @_;
    $irc->$cb("SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol\n");
  };
  $connection->url->parse("irc://$server");
  $connection->connect(sub { $err = $_[1] });
  like $log, qr{^\d+\S+\s\[info\] \S+ does not support SSL/TLS\.$}m, 'logged tls';
}

$connection->_irc->emit('close');
like $log, qr{^\d+\S+\s\[info\] You \[superman\@\S+\] have quit \[Connection closed\.\]$}m, 'logged quit';
ok !$connection->{_irc}, '_irc deleted';

$connection->_irc->emit(error => 'All the things went wrong');
like $log, qr{^\d+\S+\s\[error\] All the things went wrong$}m, 'logged error';

$connection->_irc->emit(err_cannotsendtochan => {params => [undef, '#channel_name']});
like $log, qr{^\d+\S+\s\[debug\] Cannot send to channel \#channel_name\.$}m, 'logged err_cannotsendtochan';

$connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
$connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
like $log,   qr{^\d+\S+\s\[warn\] Nickname cool_nick is already in use\.$}m, 'logged err_nicknameinuse';
unlike $log, qr{\d+\S+\s\[warn\] Nickname cool_nick.*Nickname cool_nick}s,   'logged err_nicknameinuse once';

$connection->_irc->emit(err_nosuchnick => {params => [undef, '#channel_name']});
like $log, qr{^\d+\S+\s\[debug\] No such nick or channel \#channel_name.$}m, 'logged err_nosuchnick';

$connection->_irc->emit(irc_error => {params => ['Yikes!', 'All the things went wrong']});
like $log, qr{^\d+\S+\s\[error\] Yikes! All the things went wrong$}m, 'logged irc_error';

$connection->_irc->emit(irc_rpl_yourhost =>
    {params => [undef, 'Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2']});
like $log,
  qr{^\d+\S+\s\[info\] \QYour host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2\E$}m,
  'logged irc_rpl_yourhost';

done_testing;
