use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;
use List::Util 'sum';

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user;

diag 'jhthorsen connections';
$user = $core->user({email => 'jhthorsen@cpan.org'})->save;
$user->connection({name => 'localhost', protocol => 'irc'})->tap(sub { shift->url->parse('irc://localhost') })->save;
$user->connection({name => 'magnet',    protocol => 'irc'})->tap(sub { shift->url->parse('irc://irc.perl.org') })->save;

diag 'mramberg connections';
$user = $core->user({email => 'mramberg@cpan.org'})->save;
$user->connection({name => 'freenode', protocol => 'irc'})
  ->tap(sub { shift->url->parse('irc://chat.freenode.net:6697') })->save;
$user->connection({name => 'localhost', protocol => 'Irc'})->tap(sub { shift->url->parse('irc://127.0.0.1') })
  ->state('disconnected')->save;
$user->connection({name => 'magnet', protocol => 'irc'})->tap(sub { shift->url->parse('irc://irc.perl.org') })->save;

diag 'restart core';
$core = Convos::Core->new(backend => Convos::Core::Backend::File->new);

my %connect;
Mojo::Util::monkey_patch(
  'Convos::Core::Connection::Irc',
  connect => sub {
    $connect{$_[0]->url->host_port}++;
    Mojo::IOLoop->stop if sum(values %connect) == 4;
  }
);

$ENV{CONVOS_CONNECT_DELAY} = 0.05;
$core->start for 0 .. 4;    # calling start() multiple times result in no-op
cmp_deeply $core->{connect_queue},
  {'chat.freenode.net' => [], 'irc.perl.org' => [obj_isa('Convos::Core::Connection::Irc')]}, 'connect_queue';
is_deeply \%connect, {'chat.freenode.net:6697' => 1, 'irc.perl.org' => 1, 'localhost' => 1},
  'started connections, except disconnected';

Mojo::IOLoop->start;
is_deeply \%connect, {'chat.freenode.net:6697' => 1, 'irc.perl.org' => 2, 'localhost' => 1},
  'started duplicate connection delayed';

done_testing;
