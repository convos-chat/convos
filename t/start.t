use Mojo::Base -strict;
use Test::More;

$ENV{CONVOS_HOME}          = 'convos-test-start';
$ENV{CONVOS_CONNECT_TIMER} = 0.002;

require Convos::Core;
require Convos::Core::Backend::File;
my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);

{
  my $user = $core->user('jhthorsen@cpan.org')->save;
  $user->connection(IRC => 'localhost', {})->tap(sub { shift->url->parse('irc://localhost') })->save;
}

{
  my $user = $core->user('mramberg@cpan.org')->save;
  $user->connection(IRC => 'freenode',  {})->tap(sub { shift->url->parse('irc://chat.freenode.net:6697') })->save;
  $user->connection(IRC => 'localhost', {})->tap(sub { shift->url->parse('irc://127.0.0.1') })->state('disconnected')
    ->save;
  $user->connection(IRC => 'perlorg', {})->tap(sub { shift->url->parse('irc://irc.perl.org') })->save;
}

diag 'restart core';
$core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
$core->start for 0 .. 10;    # should only start once
my %connect;
Mojo::Util::monkey_patch('Mojo::IRC::UA', connect => sub { $connect{$_[0]->server}++ });
Mojo::IOLoop->timer(0.2 => sub { Mojo::IOLoop->stop });    # should be long enough
Mojo::IOLoop->start;
is_deeply [sort keys %connect], [qw( chat.freenode.net:6697 irc.perl.org localhost )],
  'started connections, except disconnected';

File::Path::remove_tree($ENV{CONVOS_HOME});

done_testing;
