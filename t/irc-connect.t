#!perl
BEGIN {
  $ENV{CONVOS_CONNECT_DELAY} = 0.1;
  $ENV{CONVOS_GENERATE_CERT} = 1;
  $ENV{CONVOS_SKIP_CONNECT}  = 1;
}
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;
use Test::Deep;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my ($connection, $user);

$server->subtest(
  'setup' => sub {
    $user = $core->user({email => 'test.user@example.com'});
    $core->start;    # make sure the reconnect timer is started
    $user->save_p->$wait_success('save user');

    $connection = $user->connection({url => 'irc://example'});
    $connection->conversation({name => '#convos'});
    $connection->conversation({name => 'private_ryan'});
    $connection->save_p->$wait_success('save connection');
    is $connection->url->query->param('tls'), undef, 'initial tls value';
  }
);

$server->subtest(
  'on_connect_commands' => sub {
    my @on_connect_commands
      = ('/msg NickServ identify s3cret', '/SleeP  0.1 ', '/msg superwoman you are too cool');
    $connection->on_connect_commands([@on_connect_commands]);

    my $test_user_command = sub {
      my ($conn, $msg) = @_;
      is_deeply $msg->{params}, [qw(test_user 0 * https://convos.chat)],
        'got expected USER command';
    };
    $server->client($connection)->server_event_ok('_irc_event_nick')
      ->server_event_ok('_irc_event_user', $test_user_command)->server_write_ok(['welcome.irc'])
      ->client_event_ok('_irc_event_rpl_welcome')->server_event_ok('_irc_event_privmsg')
      ->server_write_ok(['identify.irc'])->server_event_ok('_irc_event_join')
      ->server_write_ok(['join-convos.irc'])->client_event_ok('_irc_event_join')
      ->client_event_ok('_irc_event_rpl_topic')->client_event_ok('_irc_event_rpl_topicwhotime')
      ->client_event_ok('_irc_event_rpl_namreply')->client_event_ok('_irc_event_rpl_endofnames')
      ->server_event_ok('_irc_event_whois')->server_write_ok(['whois.irc'])
      ->client_event_ok('_irc_event_rpl_endofwhois')->process_ok;

    is_deeply($connection->on_connect_commands,
      [@on_connect_commands], 'on_connect_commands still has the same elements');

    $server->client_states_ok([
      [frozen     => superhashof({conversation_id => '#convos',      frozen => 'Not connected.'})],
      [frozen     => superhashof({conversation_id => 'private_ryan', frozen => 'Not connected.'})],
      [connection => superhashof({state           => 'connecting'})],
      [info       => superhashof({nick            => 'superman'})],
      [connection => superhashof({state           => 'connected'})],
      [info       => superhashof({nick            => 'superman'})],
      [frozen     => superhashof({conversation_id => '#convos',      frozen => '', topic => ''})],
      [frozen     => superhashof({conversation_id => '#convos',      topic  => 'some cool topic'})],
      [frozen     => superhashof({conversation_id => 'private_ryan', frozen => ''})],
    ]);
  }
);

$server->subtest(
  'reconnect on ssl error' => sub {
    $connection->disconnect_p->$wait_success('disconnect');
    $connection->url(Mojo::URL->new('irc://irc.example.com'));
    $connection->url->query->param(local_address => '1.1.1.1');

    mock_connect(
      errors => [
        'SSL connect attempt failed error:140770FC:SSL routines:SSL23_GET_SERVER_HELLO:unknown protocol',
        'Something went wrong',
      ],
      sub {
        my $connect_args = shift;
        $connection->connect_p->catch(\&Test::More::note);
        $server->client_wait_for_states_ok(5);

        $server->client_states_ok(superbagof(
          map { ['connection', {message => ignore, state => $_}] } (
            qw(disconnecting disconnected),
            qw(connecting disconnected),
            qw(connecting disconnected),
          )
        ));

        cmp_deeply(
          $connect_args,
          superbagof(
            {
              address        => 'irc.example.com',
              port           => 6667,
              socket_options => {LocalAddr => '1.1.1.1'},
              timeout        => 20,
              tls            => 1,
              tls_cert       => re(qr{\.cert}),
              tls_key        => re(qr{\.key}),
              tls_options    => {SSL_verify_mode => 0x00},
            },
            {
              address        => 'irc.example.com',
              port           => 6667,
              socket_options => {LocalAddr => '1.1.1.1'},
              timeout        => 20
            }
          ),
          'connect args'
        );

        ok -s $connect_args->[0]{tls_cert}, 'tls_cert generated';
        ok -s $connect_args->[0]{tls_key},  'tls_key generated';
      },
    );
  }
);

$server->subtest(
  'reconnect on missing ssl module' => sub {
    mock_connect(
      errors => ['IO::Socket::SSL 1.94+ required for TLS support'],
      sub {
        $connection->disconnect_p->$wait_success('disconnect');
        $connection->url->query->remove('tls');
        $connection->connect_p->catch(\&Test::More::note);
        $server->client_wait_for_states_ok(5);

        is $connection->url->query->param('tls'), 0, 'tls off after missing module';
        $server->client_states_ok(superbagof(
          [
            connection => {
              message =>
                re(qr{IO::Socket::SSL 1\.94\+ required for TLS support\. Reconnecting in \S+}),
              state => 'disconnected'
            }
          ],
          [connection => {message => re(qr{Connecting to \S+}), state => 'connecting'}],
          [connection => {message => re(qr{Connected to \S+}),  state => 'connected'}],
        ));
      }
    );
  }
);

$server->subtest(
  'do not save frozen state by accident' => sub {
    my $core2 = Convos::Core->new(backend => 'Convos::Core::Backend::File')->start;
    Mojo::IOLoop->one_tick until $core2->ready;
    is_deeply [map { $_->frozen }
        @{$core2->get_user('test.user@example.com')->get_connection('irc-example')->conversations}],
      ['', ''], 'frozen';
  }
);

done_testing;

sub mock_connect {
  my ($cb, %args) = (pop, @_);
  my @connect_args;
  no warnings qw(redefine);
  local *Mojo::IOLoop::client = sub {
    my ($loop, $connect_args, $cb) = @_;
    push @connect_args, $connect_args;
    Mojo::IOLoop->next_tick(sub { $cb->($loop, shift @{$args{errors}}, Mojo::IOLoop::Stream->new) }
    );
    return rand;
  };
  $cb->(\@connect_args);
}

__DATA__
@@ whois.irc
:localhost 311 superman private_ryan private_ryan irc.example.com * :Convos v10.01
:localhost 318 superman private_ryan :End of /WHOIS list.
