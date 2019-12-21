#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core       = Convos::Core->new;
my $connection = $core->user({email => 'test.user@example.com'})
  ->connection({name => 'example', protocol => 'irc'});
my @state;

is $connection->url->query->param('tls'), undef, 'initiaal tls value';

note 'on_connect_commands';
my @on_connect_commands = ('/msg NickServ identify s3cret', '/msg superwoman you are too cool');
$connection->on_connect_commands([@on_connect_commands]);

$connection->dialog({name => '#convos'});
$connection->dialog({name => 'private_ryan'});

t::Helper->irc_server_connect($connection);

t::Helper->irc_server_messages(
  qr{NICK} => ['welcome.irc'],
  $connection, '_irc_event_rpl_welcome',
  qr{PRIVMSG NickServ} => ['identify.irc'],
  $connection, '_irc_event_privmsg',
  qr{JOIN} => ['join-convos.irc'],
  $connection, '_irc_event_join', $connection, '_irc_event_rpl_topic', $connection,
  '_irc_event_rpl_topicwhotime', $connection, '_irc_event_rpl_namreply', $connection,
  '_irc_event_rpl_endofnames',
  qr{ISON} => ['ison.irc'],
  $connection, '_irc_event_rpl_ison',
);

is_deeply($connection->on_connect_commands,
  [@on_connect_commands], 'on_connect_commands still has the same elements');

$connection->disconnect_p->$wait_success('disconnect_p');
$connection->url(Mojo::URL->new('irc://irc.example.com'));
$connection->on(state => sub { push @state, $_[2]->{state} if $_[1] eq 'connection' });

note 'reconnect on ssl error';
mock_connect(
  errors => [
    'SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol',
    'Something went wrong',
  ],
  sub {
    my $connect_args = shift;
    $connection->connect;
    Mojo::IOLoop->one_tick until @state == 2;

    is_deeply $connect_args->[0],
      {address => 'irc.example.com', port => 6667, timeout => 20, tls => 1, tls_verify => 0x00},
      'connect args first';
    is_deeply $connect_args->[1], {address => 'irc.example.com', port => 6667, timeout => 20},
      'connect args second';
  },
);

note 'reconnect on missing ssl module';
mock_connect(
  errors => ['IO::Socket::SSL 1.94+ required for TLS support'],
  sub {
    $connection->url->query->remove('tls');
    $connection->connect;
    Mojo::IOLoop->one_tick until @state == 3;

    is $connection->url->query->param('tls'), 0, 'tls off after missing module';
    is_deeply \@state, [qw(queued disconnected queued)], 'queued because of connect_queue';
  }
);

note 'successful connect';
mock_connect(
  stream => Mojo::IOLoop::Stream->new,
  sub {
    my $tid = Mojo::IOLoop->recurring(
      0.1 => sub {
        $core->_dequeue;
        Mojo::IOLoop->stop if @state == 4;
      }
    );
    cmp_deeply [values %{$core->{connect_queue}}], [[$connection]], 'connect_queue';
    Mojo::IOLoop->start;
    Mojo::IOLoop->remove($tid);
    is_deeply \@state, [qw(queued disconnected queued connected)], 'connected';
  }
);

done_testing;

sub mock_connect {
  my ($cb, %args) = (pop, @_);
  my @connect_args;
  no warnings 'redefine';
  local *Mojo::IOLoop::client = sub {
    my ($loop, $connect_args, $cb) = @_;
    push @connect_args, $connect_args;
    Mojo::IOLoop->next_tick(sub { $cb->($loop, shift @{$args{errors}}, $args{stream}) });
    return rand;
  };
  $cb->(\@connect_args);
}
