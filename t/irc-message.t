use t::Helper;
use Test::Mojo::IRC -basic;
use Mojo::IOLoop;
use Convos::Core;
use Convos::Core::Backend::File;

my @date = split '-', Time::Piece->new->strftime('%Y-%m');
my $core = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $t = t::Helper->connect_to_irc($connection);

$connection->_irc->emit(
  irc_privmsg => {
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['#convos', 'not a superdupersuperman?']
  }
);
is($user->unread, 0, 'No unread messages');
like slurp_log("#convos"), qr{\Q<Supergirl> not a superdupersuperman?\E}m, 'normal message';

$connection->_irc->emit(irc_privmsg =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['#convos', 'Hey SUPERMAN!']});
like slurp_log("#convos"), qr{\Q<Supergirl> Hey SUPERMAN!\E}m, 'notification';

my ($err, $notifications);
$core->get_user('superman@example.com')
  ->notifications({}, sub { $notifications = pop; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
ok delete $notifications->[0]{ts}, 'notifications has timestamp';
is($user->unread, 1, 'One unread messages');
is_deeply $notifications,
  [
  {
    connection_id => 'irc-localhost',
    dialog_id     => '#convos',
    from          => 'Supergirl',
    message       => 'Hey SUPERMAN!',
    type          => 'private'
  }
  ],
  'notifications';

$connection->_irc->emit(irc_privmsg =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', 'does this work?']}
);
like slurp_log("supergirl"), qr{\Q<Supergirl> does this work?\E}m, 'private message';

$connection->_irc->emit(ctcp_action =>
    {prefix => 'jhthorsen!jhthorsen@i.love.debian.org', params => ['#convos', "will be back"]});
like slurp_log("#convos"), qr{\Q* jhthorsen will be back\E}m, 'ctcp_action';

# test stripping away invalid characters in a message
$connection->send(
  "#convos" => "\n/me will be\a back again\n",
  sub { $err = $_[1]; Mojo::IOLoop->stop }
);
Mojo::IOLoop->start;
is $err, '', 'invalid characters was filtered';
like slurp_log("#convos"), qr{\Q* superman will be back again\E}m, 'loopback ctcp_action';

$connection->send("#convos" => "some regular message", sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;
like slurp_log("#convos"), qr{\Q<superman> some regular message\E}m, 'loopback private';

$connection->_irc->emit(irc_notice =>
    {prefix => 'Supergirl!super.girl@i.love.debian.org', params => ['superman', "notice this?"]});
like slurp_log("supergirl"), qr{\Q-Supergirl- notice this?\E}m, 'irc_notice';

$connection->_irc->emit(
  irc_privmsg => {
    prefix => 'superduper!super.duper@i.love.debian.org',
    params => ['#convos', 'foo-bar-baz, yes?']
  }
);
like slurp_log("#convos"), qr{\Q<superduper> foo-bar-baz, yes?\E}m, 'superduper';

done_testing;

sub slurp_log {
  Mojo::Util::slurp(
    File::Spec->catfile(
      $FindBin::Bin, File::Spec->updir,
      qw(local test-irc-message-t superman@example.com irc-localhost),
      @date, "$_[0].log"
    )
  );
}
