#!perl
use lib '.';
use Convos::Core;
use Convos::Core::Backend::File;
use List::Util qw(sum);
use Time::HiRes qw(time);
use t::Helper;

$ENV{CONVOS_CONNECT_DELAY} = 0.2;

my $core = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $q    = Convos::Core::Connection->new->queue;

Mojo::Util::monkey_patch(
  'Mojo::IOLoop',
  client => sub {
    my ($loop, $connect_args, $cb) = @_;
    $core->emit(connect_args => $connect_args);
    Mojo::IOLoop->next_tick(sub { $loop->$cb('', Mojo::IOLoop::Stream->new) });
  }
);

subtest 'jhthorsen connections' => sub {
  my $user = $core->user({email => 'jhthorsen@cpan.org', uid => 42});
  $user->save_p->$wait_success('save_p');

  # 1: oragono.local connects instantly
  $core->connection_profile({url => 'irc://oragono.local'})->skip_queue(true)
    ->save_p->$wait_success('save_p');
  $user->connection({url => 'irc://oragono.local'})->save_p->$wait_success('save_p');

  # 2: instant or queued
  $user->connection({connection_id => 'irc-magnet'})
    ->tap(sub { shift->url->parse('irc://irc.perl.org') })->save_p->$wait_success('save_p');
  $user->connection({connection_id => 'irc-magnet2'})
    ->tap(sub { shift->url->parse('irc://irc.perl.org') })->save_p->$wait_success('save_p');
};

subtest 'mramberg connections' => sub {
  my $user = $core->user({email => 'mramberg@cpan.org', uid => 32});
  $user->save_p->$wait_success('save_p');

  # 0: will not be connected
  my $conn_0 = $user->connection({url => 'irc://oragono.local'});
  $conn_0->wanted_state('disconnected')->url->parse('irc://127.0.0.1');
  $conn_0->save_p->$wait_success('save_p');

  # 2: instant or queued
  $user->connection({url => 'irc://libera'})
    ->tap(sub { shift->url->parse('irc://irc.libera.chat:6697') })->save_p;
  $user->connection({url => 'irc://magnet'})->tap(sub { shift->url->parse('irc://irc.perl.org') })
    ->save_p;
};

subtest 'restart core' => sub {
  my ($connected_p, $ready_p) = map { Mojo::Promise->new } 1 .. 2;
  $core = Convos::Core->new(backend => 'Convos::Core::Backend::File');
  $core->once(ready => sub { $ready_p->resolve });

  my ($t0, @connect) = (time);
  my $on_connect_args_cb = $core->on(
    connect_args => sub {
      my ($core, $connect_args) = @_;
      push @connect,
        [$connect_args->{address}, $q->size($connect_args->{address}), 100 * (time - $t0)];
      $connected_p->resolve if @connect >= 5;
    }
  );

  $core->start for 0 .. 4;    # calling start() multiple times does not do anything
  Mojo::Promise->race(Mojo::Promise->all($ready_p, $connected_p), Mojo::Promise->timeout(2))->wait;

  local $TODO = 'These tests fails on github';

  # Example test result from github:
  # [
  #   ['oragono.local',   0, '17.2949075698853'],
  #   ['irc.libera.chat', 1, '19.5363998413086'],
  #   ['irc.perl.org',    3, '21.540904045105'],
  #   ['irc.perl.org',    2, '53.5423040390015'],
  #   ['irc.perl.org',    1, '80.3494930267334']
  # ]

  cmp_deeply(
    [@connect[0 .. 2]],
    bag(
      ['irc.libera.chat', 1, num(7, 7)],
      ['irc.perl.org',    3, num(7, 7)],
      ['oragono.local',   0, num(7, 7)],
    ),
    'three first are almost at the same time'
  ) or diag explain \@connect;
  cmp_deeply(
    [@connect[3 .. 4]],
    bag(['irc.perl.org', 2, num(40, 10)], ['irc.perl.org', 1, num(60, 20)]),
    'the last two got queued'
  ) or diag explain \@connect;


  is $core->get_user('mramberg@cpan.org')->uid, 32, 'uid from storage';
  $core->unsubscribe(connect_args => $on_connect_args_cb);
};

done_testing;
