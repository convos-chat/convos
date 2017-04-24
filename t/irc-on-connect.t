#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Mojo::IOLoop;
use Test::Mojo::IRC -basic;

my $t          = Test::Mojo::IRC->new;
my $server     = $t->start_server;
my $core       = Convos::Core->new;
my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $stop_re    = qr{should_not_match};
my @res;

$connection->url->parse("irc://$server");
$connection->url->query->param(tls => 0) unless $ENV{CONVOS_IRC_SSL};
$connection->dialog({name => '#convos',      frozen => 'Frozen'});
$connection->dialog({name => 'private_ryan', frozen => 'Frozen'});

$t->run(
  [
    qr{NICK}             => ['main', 'welcome.irc'],
    qr{JOIN}             => ['main', 'join-convos.irc'],
    qr{PRIVMSG NickServ} => ['main', 'identify.irc'],
  ],
  sub {
    my $irc = $connection->_irc;
    $t->on(
      $irc,
      message => sub {
        my ($irc, $msg) = @_;
        push @res, $msg->{event};
        Mojo::IOLoop->stop if $msg->{event} eq 'privmsg';
      }
    );

    $connection->on_connect_commands(['/msg NickServ identify s3cret']);
    $connection->connect(sub { });
    Mojo::IOLoop->start;
  }
);

is_deeply(
  [grep { $_ !~ /nam|notice|topic/ } @res],
  [qw(rpl_welcome join privmsg)],
  'run through the correct events'
) or diag join ' ', @res;

is_deeply(
  $connection->on_connect_commands,
  ['/msg NickServ identify s3cret'],
  'on_connect_commands still has the same elements'
);

done_testing;

__DATA__
@@ join-convos.irc
:Superman20001!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman20001 #convos :some cool topic
:hybrid8.debian.local 333 Superman20001 #convos superman!superman@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman20001 = #convos :Superman @batman
:hybrid8.debian.local 366 Superman20001 #convos :End of /NAMES list.
@@ welcome.irc
:hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
@@ identify.irc
:NickServ!clark.kent\@i.love.debian.org PRIVMSG #superman :You are now identified for batman
