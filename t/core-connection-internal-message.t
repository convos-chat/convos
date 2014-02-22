BEGIN { $ENV{CONVOS_SKIP_VERSION_CHECK} = 1 }
use t::Helper;
use Convos::Core;
use Mojo::JSON 'j';

redis_do([hmset => 'user:doe:connection:magnet', nick => 'n1', server => 'localhost']);

my $core       = $t->app->core;
my $out        = $core->redis->subscribe('convos:user:doe:out');
my $connection = Convos::Core::Connection->new(login => 'doe', name => 'magnet');
my (@irc_buf, @out_buf);

$out->on(
  message => sub {
    push @out_buf, $_[1];
    Mojo::IOLoop->stop;
  }
);

{
  no warnings 'redefine';
  *Mojo::IRC::connect = sub { Mojo::IOLoop->stop; };
  *Mojo::IRC::write = sub { pop if ref $_[-1]; shift; push @irc_buf, join ' ', @_; };
}

{
  $connection->redis($core->redis);
  $connection->connect;
  Mojo::IOLoop->start;
  is $connection->_irc->nick, 'n1',  'irc nick n1';
  is $connection->_irc->user, 'doe', 'irc user doe';
}

{
  @irc_buf = ();
  @out_buf = ();
  $core->redis->publish('convos:user:doe:magnet' => 'internal WHOIS batman');
  $connection->{messages}->once(message => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  is_deeply(\@irc_buf, [':n1 WHOIS batman'], 'WHOIS batman');

  $connection->_irc->emit(
    irc_rpl_whoisuser => {command => 311, params => ['', 'batman', 'jhthorsen', 'magnet', '', 'Jan Henning Thorsen']});
  Mojo::IOLoop->start;
  $out_buf[0] = j $out_buf[0];
  delete $out_buf[0]{$_} for qw( uuid timestamp );
  is_deeply(
    \@out_buf,
    [
      {
        event    => 'whois',
        host     => 'magnet',
        internal => 1,
        network  => 'magnet',
        nick     => 'batman',
        realname => 'Jan Henning Thorsen',
        user     => 'jhthorsen',
      },
    ],
    'publish internal message back',
  );
}

{
  @irc_buf = ();
  @out_buf = ();
  $core->redis->publish('convos:user:doe:magnet' => 'internal WHOIS batman');
  $connection->{messages}->once(message => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;

  $connection->_irc->emit(irc_error => {command => 401, params => ['doe', 'batman', 'No such nick/channel']});
  Mojo::IOLoop->start;
  $out_buf[0] = j $out_buf[0];
  delete $out_buf[0]{$_} for qw( uuid timestamp );
  is_deeply(
    \@out_buf,
    [
      {event => 'whois', host => '', internal => 1, network => 'magnet', nick => 'batman', realname => '', user => '',},
    ],
    'publish internal message back on error',
  );
}

done_testing;
