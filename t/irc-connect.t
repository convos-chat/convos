#!perl
BEGIN { $ENV{CONVOS_SKIP_CONNECT} = 1 }
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;
use Test::Deep;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user   = $core->user({email => 'test.user@example.com'});
$user->save_p->$wait_success;

my $connection = $user->connection({name => 'example', protocol => 'irc'});
$connection->conversation({name => '#convos'});
$connection->conversation({name => 'private_ryan'});
$connection->save_p->$wait_success;

my (@connection_state, @state);
$connection->on(
  state => sub {
    shift;
    push @connection_state, $_[1]->{state} if $_[0] eq 'connection';
    push @state, [@_];
  }
);

is $connection->url->query->param('tls'), undef, 'initial tls value';

note 'on_connect_commands';
my @on_connect_commands
  = ('/msg NickServ identify s3cret', '/SleeP  0.1 ', '/msg superwoman you are too cool');
$connection->on_connect_commands([@on_connect_commands]);

my $test_user_command = sub {
  my ($conn, $msg) = @_;
  is_deeply $msg->{params}, [qw(test_user 0 * https://convos.chat)], 'got expected USER command';
};
$server->client($connection)->server_event_ok('_irc_event_nick')
  ->server_event_ok('_irc_event_user', $test_user_command)->server_write_ok(['welcome.irc'])
  ->client_event_ok('_irc_event_rpl_welcome')->server_event_ok('_irc_event_privmsg')
  ->server_write_ok(['identify.irc'])->server_event_ok('_irc_event_join')
  ->server_write_ok(['join-convos.irc'])->client_event_ok('_irc_event_join')
  ->client_event_ok('_irc_event_rpl_topic')->client_event_ok('_irc_event_rpl_topicwhotime')
  ->client_event_ok('_irc_event_rpl_namreply')->client_event_ok('_irc_event_rpl_endofnames')
  ->server_event_ok('_irc_event_ison')->server_write_ok(['ison.irc'])
  ->client_event_ok('_irc_event_rpl_ison')->process_ok('on_connect_commands');

is_deeply($connection->on_connect_commands,
  [@on_connect_commands], 'on_connect_commands still has the same elements');

cmp_deeply(
  [shift @state, shift @state],
  superbagof(
    [frozen => superhashof({conversation_id => '#convos',      frozen => 'Not connected.'})],
    [frozen => superhashof({conversation_id => 'private_ryan', frozen => 'Not connected.'})],
  ),
  'frozen'
);

cmp_deeply(
  [pop @state, pop @state],
  superbagof(
    [frozen => superhashof({conversation_id => '#convos',      frozen => ''})],
    [frozen => superhashof({conversation_id => 'private_ryan', frozen => ''})],
  ),
  'unfroze'
);

$connection->disconnect_p->$wait_success('disconnect_p');
$connection->url(Mojo::URL->new('irc://irc.example.com'));

note 'reconnect on ssl error';
@connection_state = ();
mock_connect(
  errors => [
    'SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol',
    'Something went wrong',
  ],
  sub {
    my $connect_args = shift;
    $connection->connect_p->wait;
    Mojo::IOLoop->one_tick until @connection_state == 2;

    cmp_deeply $connect_args->[0],
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
    $connection->connect_p->wait;
    Mojo::IOLoop->one_tick until @connection_state == 3;

    is $connection->url->query->param('tls'), 0, 'tls off after missing module';
    is_deeply \@connection_state, [qw(queued disconnected queued)],
      'queued because of connect_queue';
  }
);

note 'successful connect';
mock_connect(
  stream => Mojo::IOLoop::Stream->new,
  sub {
    my $tid = Mojo::IOLoop->recurring(
      0.1 => sub {
        $core->_dequeue;
        Mojo::IOLoop->stop if @connection_state == 4;
      }
    );
    cmp_deeply [values %{$core->{connect_queue}}], [[$connection]], 'connect_queue';
    Mojo::IOLoop->start;
    Mojo::IOLoop->remove($tid);
    is_deeply \@connection_state, [qw(queued disconnected queued connected)], 'connected';
  }
);

my $core2 = Convos::Core->new(backend => 'Convos::Core::Backend::File')->start;
Mojo::IOLoop->one_tick until $core2->ready;
is_deeply [map { $_->frozen }
    @{$core2->get_user('test.user@example.com')->get_connection('irc-example')->conversations}],
  ['', ''], 'did not save frozen state on accident';

done_testing;

sub core { Convos::Core->new(backend => 'Convos::Core::Backend::File') }

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
