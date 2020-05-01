#!perl
BEGIN { $ENV{CONVOS_MAX_BULK_MESSAGE_SIZE} = 5 }

use lib '.';
use t::Helper;
use Mojo::File 'path';
use Mojo::IOLoop;
use Convos::Core;
use Convos::Core::Backend::File;

my $core       = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user       = $core->user({email => 'superman@example.com'});
my $connection = $user->connection({name => 'localhost', protocol => 'irc'});

my $user_home = $core->home->child('superman@example.com');

my $err;
$connection->send_p('', 'whatever')->catch(sub { $err = shift })->$wait_success('send_p');
like $err, qr{without target}, 'send: without target';

$connection->send_p('#test_convos' => '0')->catch(sub { $err = shift })->$wait_success('send_p');
like $err, qr{Not connected}i, 'send: not connected';

t::Helper->irc_server_connect($connection);

t::Helper->irc_server_messages(
  qr{NICK}    => ['welcome.irc'],
  qr{USER}    => ":Supergirl!sg\@example.com PRIVMSG #convos :not a superdupersuperman?\r\n",
  $connection => '_irc_event_privmsg',
);

note 'notifications';
is $user->unread, 0, 'notifications';
like slurp_log('#convos'), qr{\Q<Supergirl> not a superdupersuperman?\E}m, 'normal message';

t::Helper->irc_server_messages(
  from_server =>
    ":Supergirl!sg\@example.com PRIVMSG superman :Hey! Do you get any notifications?\r\n",
  $connection => '_irc_event_privmsg',
  from_server => ":Supergirl!sg\@example.com PRIVMSG superman :Yikes! how are you?\r\n",
  $connection => '_irc_event_privmsg',
  from_server =>
    ":superman!sm\@example.com PRIVMSG #convos :What if I mention myself as superman?\r\n",
  $connection => '_irc_event_privmsg',
  from_server =>
    ":Supergirl!sg\@example.com PRIVMSG #convos :But... SUPERMAN, what about in a channel?\r\n",
  $connection => '_irc_event_privmsg',
  from_server =>
    ":Supergirl!sg\@example.com PRIVMSG #convos :Or what about a normal message in a channel?\r\n",
  $connection => '_irc_event_privmsg',
);
like slurp_log('#convos'), qr{\Q<Supergirl> But... SUPERMAN, what about in a channel?\E}m,
  'notification';

my $notifications;
$core->get_user('superman@example.com')->notifications_p({})->then(sub { $notifications = pop; })
  ->$wait_success('notifications');
ok delete $notifications->{messages}[0]{ts}, 'notifications has timestamp';
is $user->unread, 1, 'One unread messages';
is_deeply(
  $notifications->{messages},
  [{
    connection_id => 'irc-localhost',
    dialog_id     => '#convos',
    from          => 'Supergirl',
    message       => 'But... SUPERMAN, what about in a channel?',
    type          => 'private'
  }],
  'notifications'
);

note 'highlight_keywords';
$user->highlight_keywords(['normal', 'Yikes', ' '])->_normalize_attributes;

t::Helper->irc_server_messages(
  from_server =>
    ":Supergirl!sg\@example.com PRIVMSG #convos :Or what about a message with space in a channel?\r\n",
  $connection => '_irc_event_privmsg',
  from_server => ":Supergirl!sg\@example.com PRIVMSG #convos :Yikes! yikes:/\r\n",
  $connection => '_irc_event_privmsg',
  from_server =>
    ":Supergirl!sg\@example.com PRIVMSG #convos :Or what about a NORMAL message in a channel?\r\n",
  $connection => '_irc_event_privmsg',
  from_server => ":Supergirl!sg\@example.com PRIVMSG #convos :Some other random message\r\n",
  $connection => '_irc_event_privmsg',
);
$core->get_user('superman@example.com')->notifications_p({})->then(sub { $notifications = pop; })
  ->$wait_success('notifications');
delete $_->{ts} for @{$notifications->{messages}};
is_deeply(
  $notifications->{messages},
  [
    map {
      +{
        connection_id => 'irc-localhost',
        dialog_id     => '#convos',
        from          => 'Supergirl',
        message       => $_,
        type          => 'private'
      }
    } 'But... SUPERMAN, what about in a channel?',
    'Yikes! yikes:/',
    'Or what about a NORMAL message in a channel?',
  ],
  'notifications'
);
is $user->unread, 3, 'One unread messages';

t::Helper->irc_server_messages(
  from_server => ":Supergirl!sg\@example.com PRIVMSG superman :does this work?!\r\n",
  $connection => '_irc_event_privmsg',
);
like slurp_log("supergirl"), qr{\Q<Supergirl> does this work?\E}m, 'private message';

t::Helper->irc_server_messages(
  from_server =>
    ":jhthorsen!jhthorsen\@example.com PRIVMSG #convos :\x{1}ACTION convos rocks!\x{1}\r\n",
  $connection => '_irc_event_ctcp_action',
);
like slurp_log('#convos'), qr{\Q* jhthorsen convos rocks\E}m, 'ctcp_action';

note 'test stripping away invalid characters in a message';
$connection->send_p('#convos' => "\n/me will be\a back\n")->$wait_success('send_p action');
like slurp_log('#convos'), qr{\Q* superman will be back\E}m, 'loopback ctcp_action';

$connection->send_p('#convos' => "some regular / message")->$wait_success('send_p regular');
like slurp_log('#convos'), qr{\Q<superman> some regular / message\E}m, 'loopback private';

$connection->send_p('#convos' => "/say /me is a command")->$wait_success('send_p /say');
like slurp_log('#convos'), qr{\Q<superman> /me is a command\E}m, 'me is a command';

t::Helper->irc_server_messages(
  from_server => ":Supergirl!sg\@example.com NOTICE superman :notice this?\r\n",
  $connection => '_irc_event_notice',
);
like slurp_log("supergirl"), qr{\Q-Supergirl- notice this?\E}m, 'irc_notice';

t::Helper->irc_server_messages(
  from_server => ":superduper!sd\@example.com PRIVMSG #convos foo-bar-baz, yes?\r\n",
  $connection => '_irc_event_privmsg',
);
like slurp_log('#convos'), qr{\Q<superduper> foo-bar-baz, yes?\E}m, 'superduper';

note 'split messages';
my $message_514 = path('t/data/long-message-514.txt')->slurp;
chomp $message_514;
$connection->send_p('#convos' => join "\n", $message_514, $message_514)
  ->$wait_success('send_p long x2');
like slurp_log('#convos'), qr{
  .*<superman>\sPhasellus.*?rhoncus\r?\n
  .*<superman>\samet\.\r?\n
  .*<superman>\sPhasellus.*?rhoncus\r?\n
  .*<superman>\samet\.\r?\n
}sx, 'split long message';

$connection->send_p('#convos' => join ' ', 'cool beans', ('xyz' x 171), 'a b c ')
  ->$wait_success('send_p long word');
like slurp_log('#convos'), qr{
  .*<superman>\scool\sbeans\r?\n
  .*<superman>\s(xyz)+x\r?\n
  .*<superman>\syz\sa\sb\sc\r?\n
}sx, 'split long word';

my $message_34243 = path('t/data/long-message-34243.txt')->slurp;
require Convos::Plugin::Files::File;
$core->backend->on(message_to_paste => 'Convos::Plugin::Files::File');
$connection->send_p('#convos' => $message_34243)->$wait_success('send_p super long message');
like slurp_log('#convos'), qr{file/1/ktGW3DYcdBw5nB54}, 'created paste from long message';
chomp $message_34243;
is $user_home->child('upload/ktGW3DYcdBw5nB54.data')->slurp, $message_34243, 'paste matches';

note 'single space';
$connection->send_p('#convos' => ' ')->$wait_success('send_p single space');
like slurp_log('#convos'), qr{<superman>\s\s\r?\n}, 'single space in log';

note 'paste';
my $long_line            = join '', map {$_} 0 .. 150;
my $long_line_with_space = "$long_line $long_line";
$long_line = "$long_line$long_line";
my @sent = (
  "a\nb\nc\nd\ne\nf\ng",
  "abc\n$long_line\nghi\n$long_line_with_space" x 5,
  "abc\ndef\nghi\n" x 200,
);
my @msg;
local *Convos::Core::Connection::Irc::_irc_event_privmsg = sub { push @msg, pop(@_)->{raw_line} };
$connection->send_p('#convos' => $sent[0])->$wait_success('short paste message');

$connection->send_p('#convos' => $sent[1])->$wait_success('long paste message');
$connection->send_p('#convos' => $sent[2])->$wait_success('many short lines paste message');

is_deeply(
  \@msg,
  [
    ':superman PRIVMSG #convos :file/1/Yf317MsGajxcw0Kj',
    ':superman PRIVMSG #convos :file/1/4vprpCqxzuY25LVx',
    ':superman PRIVMSG #convos :file/1/NaqVcgy4F1292BqA',
  ],
  'created paste messages',
);

for my $msg (@msg) {
  my $basename = $msg =~ m!/(\w+)$! ? $1 : 'unknown';
  my $file     = path $user_home, 'upload', split '/', "$basename.data";
  my $sent     = shift @sent;
  chomp $sent;    # TODO: Is this correct?
  is $file->slurp, $sent, "paste file $basename match sent data";
}

done_testing;

sub slurp_log {
  my @date = split '-', Time::Piece->new->strftime('%Y-%m');
  return path($user_home, 'irc-localhost', @date, "$_[0].log")->slurp;
}
