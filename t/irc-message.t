use Mojo::Base -strict;
use Mojo::IOLoop;
use Convos::Core;
use Test::Deep;
use Test::More;

my $core       = Convos::Core->new;
my $user       = $core->user('superman@example.com');
my $connection = $user->connection(IRC => 'localhost');
my @log;

$core->backend->on(
  room => sub {
    my ($backend, $room) = @_;
    push @log, sprintf "--- room %s\n", $room->id;
    $room->on(
      log => sub {
        my ($room, $level, $message) = @_;
        push @log, sprintf "%s [%s] %s\n", $room->id, $level, $message;
      }
    );
  }
);

$connection->_irc->emit(irc_privmsg =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'not a ssuperman highlight']});
like "@log", qr{^--- room \#convos$}m, 'convos room';
like "@log", qr{\#\Qconvos [info] <Supergirl> not a ssuperman highlight\E}m, 'normal message';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'highlight -superman?']});
like "@log", qr{\#\Qconvos [warn] <Supergirl> highlight -superman?\E}m, 'highlight message in channel';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', 'does this work?']});
like "@log", qr{--- room supergirl}m, 'supergirl room';
like "@log", qr{\Qsupergirl [warn] <Supergirl> does this work?\E}m, 'private message';

$connection->_irc->emit(
  ctcp_action => {prefix => 'jhthorsen!jhthorsen@i.love.debian.org', params => ['#convos', "me said something"]});
like "@log", qr{\#\Qconvos [info] * jhthorsen me said something\E}m, 'ctcp_action';

$connection->_irc->emit(
  irc_notice => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', "notice this?"]});
like "@log", qr{\Qsupergirl [warn] -Supergirl- notice this?\E}m, 'irc_notice';

$connection->url->query->param(highlight => 'foo-bar-baz');
$connection->_irc->emit(irc_privmsg =>
    {prefix => 'superduper!super.duper@i.love.debian.org', params => ['#convos', 'highlight foo-bar-baz, yes?']});
like "@log", qr{\#\Qconvos [warn] <superduper> highlight foo-bar-baz, yes?\E}m, 'highlight words';

done_testing;
