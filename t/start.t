BEGIN { $ENV{CONVOS_CONNECT_TIMER} = 0.002 }
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);

{
  my $user = $core->user({email => 'jhthorsen@cpan.org'})->save;
  $user->connection({name => 'localhost', protocol => 'irc'})->tap(sub { shift->url->parse('irc://localhost') })->save;
}

{
  my $user = $core->user({email => 'mramberg@cpan.org'})->save;
  $user->connection({name => 'freenode', protocol => 'irc'})
    ->tap(sub { shift->url->parse('irc://chat.freenode.net:6697') })->save;
  $user->connection({name => 'localhost', protocol => 'Irc'})->tap(sub { shift->url->parse('irc://127.0.0.1') })
    ->state('disconnected')->save;
  $user->connection({name => 'perlorg', protocol => 'irc'})->tap(sub { shift->url->parse('irc://irc.perl.org') })->save;
}

diag 'restart core';
$core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my %connect;
Mojo::Util::monkey_patch('Mojo::IRC::UA', connect => sub { $connect{$_[0]->server}++ });
$core->start for 0 .. 4;    # calling start() multiple times result in no-op
Mojo::IOLoop->timer(0.3 => sub { Mojo::IOLoop->stop });    # should be long enough
Mojo::IOLoop->start;

is_deeply \%connect, {'chat.freenode.net:6697' => 1, 'irc.perl.org' => 1, 'localhost' => 1},
  'started connections, except disconnected';

done_testing;
