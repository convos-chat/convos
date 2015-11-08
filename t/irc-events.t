use t::Helper;
use Test::Mojo::IRC -basic;
use Mojo::IOLoop;
use Convos::Core;

my $t          = Test::Mojo::IRC->new;
my $server     = $t->start_server;
my $core       = Convos::Core->new;
my $user       = $core->user('superman@example.com', {});
my $connection = $user->connection({name => 'localhost', protocol => 'Irc'});
my @captured;

for my $e ($user->EVENTS) {
  $user->on($e => sub { shift; shift; push @captured, $e, @_ });
}

captured_is(
  sub {
    $connection->url->parse('irc://127.0.0.1');
    $connection->_irc->emit('close');
    ok !$connection->{_irc}, '_irc deleted';
  },
  [state => 'connecting', 'You [superman@127.0.0.1] have quit.'],
  'close'
);

captured_is(
  sub {
    $connection->_irc->emit(error => 'All the things went wrong');
  },
  [
    message => $connection,
    {from => '127.0.0.1', highlight => TRUE, message => 'All the things went wrong', type => 'notice'}
  ],
  'error'
);

captured_is(
  sub {
    $connection->_irc->emit(err_cannotsendtochan => {params => [undef, '#channel_name']});
  },
  [
    message => $connection,
    {from => '127.0.0.1', highlight => TRUE, message => 'Cannot send to channel #channel_name.', type => 'notice'}
  ],
  'err_cannotsendtochan'
);

captured_is(
  sub {
    $connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
    $connection->_irc->emit(err_nicknameinuse => {params => [undef, 'cool_nick']});
  },
  [
    message => $connection,
    {from => '127.0.0.1', highlight => TRUE, message => 'Nickname cool_nick is already in use.', type => 'notice'}
  ],
  'err_nicknameinuse twice, but only one event'
);

captured_is(
  sub {
    $connection->_irc->emit(err_nosuchnick => {params => [undef, '#channel_name']});
  },
  [
    message => $connection->conversation('#channel_name'),
    {from => '127.0.0.1', highlight => TRUE, message => 'No such nick or channel.', type => 'notice'},
    message => $connection,
    {from => '127.0.0.1', highlight => FALSE, message => 'No such nick or channel #channel_name.', type => 'notice'},
  ],
  'err_nosuchnick'
);

captured_is(
  sub {
    $connection->_irc->emit(irc_error => {params => ['Yikes!', 'All the things went wrong']});
  },
  [
    message => $connection,
    {from => '127.0.0.1', highlight => TRUE, message => 'Yikes! All the things went wrong', type => 'notice'}
  ],
  'irc_error'
);

captured_is(
  sub {
    $connection->_irc->emit(irc_rpl_yourhost =>
        {params => [undef, 'Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2']}
    );
  },
  [
    message => $connection,
    {
      from      => '127.0.0.1',
      highlight => FALSE,
      message   => 'Your host is hybrid8.debian.local[0.0.0.0/6667], running version hybrid-1:8.2.0+dfsg.1-2',
      type      => 'notice'
    }
  ],
  'irc_rpl_yourhost'
);

done_testing;

sub captured_is {
  my ($cb, $expected, $desc) = @_;
  @captured = ();
  $cb->();
  is_deeply \@captured, $expected, $desc;
}
