BEGIN { $ENV{CONVOS_CONNECT_TIMER} = 0.002 }
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);

{
  my $user = $core->user('jhthorsen@cpan.org')->save;
  $user->connection(irc => 'localhost', {})->tap(sub { shift->url->parse('irc://localhost') })->save;
}

{
  my $user = $core->user('mramberg@cpan.org')->save;
  $user->connection(irc => 'freenode',  {})->tap(sub { shift->url->parse('irc://chat.freenode.net:6697') })->save;
  $user->connection(Irc => 'localhost', {})->tap(sub { shift->url->parse('irc://127.0.0.1') })->state('disconnected')
    ->save;
  $user->connection(irc => 'perlorg', {})->tap(sub { shift->url->parse('irc://irc.perl.org') })->save;
  ok !$user->connection(Irc => 'localhost', {})->loaded, 'connection not loaded';
}

diag 'restart core';
$core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
$core->start for 0 .. 20;    # should only start once
my %connect;
Mojo::Util::monkey_patch('Mojo::IRC::UA', connect => sub { $connect{$_[0]->server}++ });
Mojo::IOLoop->timer(0.3 => sub { Mojo::IOLoop->stop });    # should be long enough
Mojo::IOLoop->start;
is_deeply [sort keys %connect], [qw( chat.freenode.net:6697 irc.perl.org localhost )],
  'started connections, except disconnected';

ok $core->user('jhthorsen@cpan.org')->connection(Irc => 'localhost', {})->loaded, 'connection loaded';

done_testing;
