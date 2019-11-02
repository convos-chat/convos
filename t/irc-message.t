#!perl

BEGIN {
  # To enable the long_message() test below
  $ENV{CONVOS_MAX_BULK_MESSAGE_SIZE} = 5;
}

use lib '.';
use t::Helper;
use Test::Mojo::IRC -basic;
use Mojo::IOLoop;
use Convos::Core;
use Convos::Core::Backend::File;

my @date       = split '-', Time::Piece->new->strftime('%Y-%m');
my $core       = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
my $t          = t::Helper->connect_to_irc($connection);

$connection->_irc->emit(
  message => {
    event  => 'privmsg',
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['#convos', 'not a superdupersuperman?']
  }
);
is($user->unread, 0, 'No unread messages');
like slurp_log('#convos'), qr{\Q<Supergirl> not a superdupersuperman?\E}m, 'normal message';

$connection->_irc->emit(
  message => {
    event  => 'privmsg',
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['#convos', 'Hey SUPERMAN!']
  }
);
like slurp_log('#convos'), qr{\Q<Supergirl> Hey SUPERMAN!\E}m, 'notification';

my ($err, $notifications);
$core->get_user('superman@example.com')
  ->notifications({}, sub { $notifications = pop; Mojo::IOLoop->stop; });
Mojo::IOLoop->start;
ok delete $notifications->[0]{ts}, 'notifications has timestamp';
is($user->unread, 1, 'One unread messages');
is_deeply $notifications,
  [{
  connection_id => 'irc-localhost',
  dialog_id     => '#convos',
  from          => 'Supergirl',
  message       => 'Hey SUPERMAN!',
  type          => 'private'
  }],
  'notifications';

$connection->_irc->emit(
  message => {
    event  => 'privmsg',
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['superman', 'does this work?']
  }
);
like slurp_log("supergirl"), qr{\Q<Supergirl> does this work?\E}m, 'private message';

$connection->_irc->emit(
  message => {
    event  => 'ctcp_action',
    prefix => 'jhthorsen!jhthorsen@i.love.debian.org',
    params => ['#convos', "convos rocks"]
  }
);
like slurp_log('#convos'), qr{\Q* jhthorsen convos rocks\E}m, 'ctcp_action';

# test stripping away invalid characters in a message
$connection->send('#convos' => "\n/me will be\a back\n", sub { $err = $_[1] });
$connection->once(message => sub { Mojo::IOLoop->next_tick(\&Mojo::IOLoop::stop) });
Mojo::IOLoop->start;
is $err, '', 'invalid characters was filtered';
like slurp_log('#convos'), qr{\Q* superman will be back\E}m, 'loopback ctcp_action';

$connection->send('#convos' => "some regular message", sub { });
$connection->once(message => sub { Mojo::IOLoop->next_tick(\&Mojo::IOLoop::stop) });
Mojo::IOLoop->start;
like slurp_log('#convos'), qr{\Q<superman> some regular message\E}m, 'loopback private';

$connection->_irc->emit(
  message => {
    event  => 'notice',
    prefix => 'Supergirl!super.girl@i.love.debian.org',
    params => ['superman', "notice this?"]
  }
);
like slurp_log("supergirl"), qr{\Q-Supergirl- notice this?\E}m, 'irc_notice';

$connection->_irc->emit(
  message => {
    event  => 'privmsg',
    prefix => 'superduper!super.duper@i.love.debian.org',
    params => ['#convos', 'foo-bar-baz, yes?']
  }
);
like slurp_log('#convos'), qr{\Q<superduper> foo-bar-baz, yes?\E}m, 'superduper';

my @messages;
my $subscriber = $connection->on(
  message => sub {
    my ($connection, $dialog, $msg) = @_;
    push @messages, $msg->{message} if $msg->{from} eq 'superman';
    Mojo::IOLoop->next_tick(\&Mojo::IOLoop::stop) if @messages == 4;
  }
);
$connection->send('#convos' => join("\n", long_message(), long_message()), sub { });
Mojo::IOLoop->start;
is_deeply [map { length $_ } @messages], [508, 5, 508, 5], 'split long messages';

$connection->unsubscribe(message => $subscriber);

done_testing;

sub long_message {
  return join ' ', 'Phasellus imperdiet mollis nibh, ut venenatis sem fringilla ut.',
    'Maecenas nulla massa, pulvinar in scelerisque ut, commodo et purus.',
    'Nunc nec libero leo. Pellentesque habitant morbi tristique senectus et',
    'netus et malesuada fames ac turpis egestas. Sed fermentum erat quis dolor',
    'aliquam mattis. Donec sodales nisl sagittis nunc ultrices porta.',
    'Aenean id facilisis mauris. Vestibulum vulputate magna a libero semper facilisis.',
    'Cras vitae leo lacus. Curabitur blandit, massa et interdum egestas, diam mi rhoncus amet.';
}

sub slurp_log {
  Mojo::File->new(qw(local test-irc-message-t superman@example.com irc-localhost),
    @date, "$_[0].log")->slurp;
}
