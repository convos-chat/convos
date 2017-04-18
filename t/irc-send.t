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

my ($err, $res);
my $stop = sub { ($err, $res) = @_[1, 2]; Mojo::IOLoop->stop };

$connection->url->parse("irc://$server");
$connection->url->query->param(tls => 0) unless $ENV{CONVOS_IRC_SSL};

$t->run(
  [],
  sub {
    $connection->send('' => '/connect', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /connect';
    is $res, undef, 'res /connect';
  }
);

# join without a channel name
$connection->send('#convos' => '/join ', $stop);
Mojo::IOLoop->start;
is $err, 'Command missing arguments.', 'missing arguments';

$t->run(
  [qr{JOIN \#convos key}, ['main', 'join-convos.irc']],
  sub {
    $connection->send('#convos' => '/join #convos key', $stop);
    Mojo::IOLoop->start;
    is $err, '', 'cmd /join #convos key';
    is $res->{topic}, 'some cool topic', 'res /join #convos key';
  }
);

$t->run(
  [qr{NICK}, ['main', 'nick-supermanx.irc']],
  sub {
    $connection->send('#does_not_matter' => '/nick supermanx', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /nick supermanx';
    is $res, undef, 'res /nick supermanx';
  }
);

$t->run(
  [],
  sub {
    $connection->send('#convos' => '/me is afk', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /say';
    is $res, undef, 'res /say';
  }
);

$t->run(
  [],
  sub {
    $connection->send('#convos' => '/say /some/stuff', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /say';
    is $res, undef, 'res /say';
  }
);

$t->run(
  [],
  sub {
    $connection->send('#convos' => '/msg somebody /some/stuff', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /say';
    is $res, undef, 'res /say';
  }
);

$t->run(
  [qr{TOPIC}, ['main', 'set-topic.irc']],
  sub {
    $connection->send('#convos' => '/topic Cool topic', $stop);
    Mojo::IOLoop->start;
    is $err, '', 'cmd /topic set';
  }
);

$t->run(
  [qr{TOPIC}, ['main', 'get-topic.irc']],
  sub {
    $connection->send("#convos" => "/topic", $stop);
    Mojo::IOLoop->start;
    is $err, '', 'cmd /topic get';
    is $res->{topic}, 'Cool topic', 'res /topic get';
  }
);

$t->run(
  [qr{PART}, ['main', 'part-does-not-matter.irc']],
  sub {
    $connection->send('#does_not_matter' => '/part', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'parting IRC channel, even if not in the channel';
    is $res, undef, 'res /part does_not_matter';
  }
);

$t->run(
  [qr{PART}, ['main', 'part-convos.irc']],
  sub {
    $connection->send('#does_not_matter' => '/part #convos', $stop);
    Mojo::IOLoop->start;
    is $err, '',    'cmd /part convos';
    is $res, undef, 'res /part convos';
  }
);

$t->run(
  [qr{JOIN \#convos}, ['main', 'join-convos.irc']],
  sub {
    ok !$connection->get_dialog('#convos'), 'not joined';
    $connection->send('#convos' => '/join #convos', $stop);
    Mojo::IOLoop->start;
    is $err, '', 'cmd /join #convos';
  }
);

$t->run(
  [qr{JOIN \#devops}, ['main', 'join-redirect.irc']],
  sub {
    $connection->send(
      '#convos' => '/join #devops',
      sub { ($err, $res) = @_[1, 2]; Mojo::IOLoop->stop }
    );
    Mojo::IOLoop->start;
    is $err, '', 'cmd /join #devops';
    ok !$connection->get_dialog('#devops'), 'not #devops';
    ok $connection->get_dialog('##devops'), 'but ##devops';
  }
);

$t->run(
  [qr{ISON batgirl}, ['main', 'ison1.irc'], qr{ISON wonderwoman}, ['main', 'ison2.irc']],
  sub {
    my $i           = 0;
    my $batgirl     = $connection->dialog({frozen => 'Not connected.', name => 'batgirl'});
    my $someone     = $connection->dialog({frozen => 'Not connected.', name => 'someone'});
    my $superman    = $connection->dialog({frozen => 'Whatever.', name => 'superman'});
    my $wonderwoman = $connection->dialog({frozen => 'Not connected.', name => 'wonderwoman'});
    my $stop        = sub { ++$i == 5 and Mojo::IOLoop->stop };
    $connection->send('' => '/ison batgirl',     sub { });
    $connection->send('' => '/ison someone',     sub { });
    $connection->send('' => '/ison superman',    sub { });
    $connection->send('' => '/ison wonderwoman', sub { });
    $connection->on(state => $stop);
    Mojo::IOLoop->start;
    is $err, '', 'cmd /ison someone';
    is $batgirl->frozen,     '',                 'batgirl is online';
    is $someone->frozen,     'User is offline.', 'someone is offline';
    is $superman->frozen,    '',                 'superman is online';
    is $wonderwoman->frozen, 'User is offline.', 'wonderwoman is offline';
    $connection->unsubscribe(state => $stop);
  }
);

$t->run(
  [],
  sub {
    $connection->send('' => '/disconnect', sub { ($err, $res) = @_[1, 2]; Mojo::IOLoop->stop });
    Mojo::IOLoop->start;
    is $err, '',    'cmd /disconnect';
    is $res, undef, 'res /disconnect';
    ok !$connection->{_irc}, 'disconnected from irc server';
  }
);

ok !$connection->get_dialog('#q1'), 'convos not in dialog list';
$connection->send('#whatever' => '/query #q1', sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;
ok $connection->get_dialog('#q1'), 'query #q1';
is $connection->get_dialog('#q1')->frozen, 'Not active in this room.', 'not in the room';

$connection->send('#whatever' => '/query query_man', sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;
ok $connection->get_dialog('query_man'), 'query query_man';
is $connection->get_dialog('query_man')->frozen, '', 'query_man is not frozen';

done_testing;

__DATA__
@@ join-convos.irc
:Superman20001!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman20001 #convos :some cool topic
:hybrid8.debian.local 333 Superman20001 #convos jhthorsen!jhthorsen@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman20001 = #convos :Superman20001 @batman
:hybrid8.debian.local 366 Superman20001 #convos :End of /NAMES list.
@@ part-does-not-matter.irc
:hybrid8.debian.local 479 Superman20001 #does_not_matter :Illegal channel name
@@ part-convos.irc
:test21362!~test96908@0::1 PART #convos
@@ nick-supermanx.irc
:Superman20001!superman@i.love.debian.org NICK :supermanx
@@ get-topic.irc
:hybrid8.debian.local 332 Superman20001 #convos :Cool topic
:hybrid8.debian.local 333 Superman20001 #convos batman_!superman@i.love.debian.org 1433007153
@@ set-topic.irc
:batman_!superman@i.love.debian.org TOPIC #convos :Cool topic
@@ join-redirect.irc
:hybrid8.debian.local 470 test_____ #devops ##devops :Forwarding to another channel
:test_____!~test12120@somehost JOIN ##devops
:hybrid8.debian.local 332 test21362 ##devops :some cool topic
:hybrid8.debian.local 333 test21362 ##devops jhthorsen!jhthorsen@i.love.debian.org 143293
:hybrid8.debian.local 353 test21362 @ ##devops :Test21362 @batman
:hybrid8.debian.local 366 test21362 ##devops :End of /NAMES list.
@@ ison1.irc
:hybrid8.debian.local 303 test21362 :Batgirl
@@ ison2.irc
:hybrid8.debian.local 303 test21362 :
:hybrid8.debian.local 303 test21362 :
:hybrid8.debian.local 303 test21362 :superman
