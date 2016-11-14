use Test::Mojo::IRC -basic;
use lib '.';
use t::Helper;

BEGIN { $ENV{CONVOS_STEAL_NICK_INTERVAL} = 0.01 }
use Convos::Core;

my $t          = Test::Mojo::IRC->start_server;
my $core       = Convos::Core->new;
my $user       = $core->user({email => 'nick.young@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $nick;

$connection->on(
  state => sub { return unless $_[1] eq 'me'; $nick = $_[2]->{nick}; Mojo::IOLoop->stop; });
$connection->url->parse(sprintf 'irc://%s?tls=0', $t->server);

$t->run(
  [
    qr{NICK nickyoung}  => ":hybrid8.debian.local 433 * nickyoung :Nickname is already in use.\n",
    qr{NICK nickyoung_} => ":hybrid8.debian.local 001 nickyoung_ :Welcome\n",
  ],
  sub {
    is $connection->url->query->param('nick'), undef, 'no nick in connect url';
    $connection->connect(sub { $_[1] and diag "connect: $_[1]" });
    is $connection->url->query->param('nick'), 'nickyoung', 'nick set in connect url';
    Mojo::IOLoop->start;
    is $nick, 'nickyoung_', 'connection nick nickyoung_';
    $connection->connect(sub { });
    is $connection->_irc->nick, 'nickyoung_', 'connect() does not change $irc->nick';
  }
);

$t->run(
  [qr{NICK nickyoung} => ":superman!clark.kent\@i.love.debian.org PRIVMSG #convos :hey\n"],
  sub {
    my $privmsg;
    $t->on($connection->_irc, irc_privmsg => sub { $privmsg++; Mojo::IOLoop->stop });
    Mojo::IOLoop->start;
    is $privmsg, 1, 'NICK command sent by recurring timer';
  }
);

$t->run(
  [qr{NICK nickyoung} => ":nickyoung_!superman\@i.love.debian.org NICK :nickyoung\n"],
  sub {
    Mojo::IOLoop->start;
    is $connection->url->query->param('nick'), 'nickyoung', 'nick set in connect url';
    is $nick, 'nickyoung', 'connection nick nickyoung';
  }
);

$t->run(
  [
    qr{NICK n2} => "",
    qr{NICK n2} => ":superman!clark.kent\@i.love.debian.org PRIVMSG #convos :me again\n",
    qr{NICK n2} => ":nickyoung!superman\@i.love.debian.org NICK :n2\n"
  ],
  sub {
    my $err;
    is $connection->nick(n2 => sub { $err = $_[1]; Mojo::IOLoop->stop; }), $connection, 'nick(n2)';
    is $connection->url->query->param('nick'), 'n2', 'nick set in connect url';
    Mojo::IOLoop->start;
    is $err,  '',   'nick set';
    is $nick, 'n2', 'connection nick n2';
  }
);

done_testing;
