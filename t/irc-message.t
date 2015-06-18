use Mojo::Base -strict;
use Mojo::IOLoop;
use Convos::Core;
use Test::Deep;
use Test::More;

my $core       = Convos::Core->new;
my $user       = $core->user('superman@example.com', {});
my $connection = $user->connection(IRC => 'localhost', {});
my @log;

$core->backend->on(
  conversation => sub {
    my ($backend, $conversation) = @_;
    push @log, sprintf "--- conversation %s\n", $conversation->id;
    $conversation->on(
      log => sub {
        my ($conversation, $level, $message) = @_;
        push @log, sprintf "%s [%s] %s\n", $conversation->id, $level, $message;
      }
    );
  }
);

$connection->_irc->emit(irc_privmsg =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'not a ssuperman highlight']});
like "@log", qr{^--- conversation \#convos$}m, 'convos conversation';
like "@log", qr{\#\Qconvos [info] <Supergirl> not a ssuperman highlight\E}m, 'normal message';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'highlight -superman?']});
like "@log", qr{\#\Qconvos [warn] <Supergirl> highlight -superman?\E}m, 'highlight message in channel';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', 'does this work?']});
like "@log", qr{--- conversation supergirl}m, 'supergirl conversation';
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
