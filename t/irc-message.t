use t::Helper;
use Mojo::IOLoop;
use Convos::Core;
use Convos::Core::Backend::File;

my @date = (localtime)[5, 4];
$date[0] += 1900;
$date[1]++;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $connection = $core->user('superman@example.com', {})->connection({name => 'localhost', protocol => 'irc'});

$connection->_irc->emit(irc_privmsg =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'not a ssuperman highlight']});
like slurp_log("#convos"), qr{\Q<Supergirl> not a ssuperman highlight\E}m, 'normal message';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'highlight -superman?']});
like slurp_log("#convos"), qr{\Q<Supergirl> highlight -superman?\E}m, 'highlight message in channel';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', 'does this work?']});
like slurp_log("supergirl"), qr{\Q<Supergirl> does this work?\E}m, 'private message';

$connection->_irc->emit(
  ctcp_action => {prefix => 'jhthorsen!jhthorsen@i.love.debian.org', params => ['#convos', "me said something"]});
like slurp_log("#convos"), qr{\Q* jhthorsen me said something\E}m, 'ctcp_action';

$connection->_irc->emit(
  irc_notice => {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', "notice this?"]});
like slurp_log("supergirl"), qr{\Q-Supergirl- notice this?\E}m, 'irc_notice';

$connection->_irc->emit(
  irc_privmsg => {prefix => 'superduper!super.duper@i.love.debian.org', params => ['#convos', 'foo-bar-baz, yes?']});
like slurp_log("#convos"), qr{\Q<superduper> foo-bar-baz, yes?\E}m, 'superduper';

done_testing;

sub slurp_log {
  Mojo::Util::slurp(
    File::Spec->catfile(qw( local test-t-irc-message-t superman@example.com irc-localhost ), @date, "$_[0].log"));
}
