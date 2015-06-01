use Mojo::Base -strict;
use Test::More;

$ENV{CONVOS_HOME}          = 'convos-test-start';
$ENV{CONVOS_CONNECT_TIMER} = 0.001;

require Convos::Core;
require Convos::Core::Backend::File;
my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $connect = 0;

{
  my $user = $core->user('jhthorsen@cpan.org')->save;
  $user->connection(IRC => 'localhost')->tap(sub { shift->url->parse('irc://localhost') })->save;
}

{
  my $user = $core->user('mramberg@cpan.org')->save;
  $user->connection(IRC => 'freenode')->tap(sub  { shift->url->parse('irc://chat.freenode.net:6697') })->save;
  $user->connection(IRC => 'localhost')->tap(sub { shift->url->parse('irc://127.0.0.1') })->state('disconnected')->save;
  $user->connection(IRC => 'perlorg')->tap(sub   { shift->url->parse('irc://irc.perl.org') })->save;
}

diag 'restart core';
$core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
$core->start;
*Mojo::IRC::UA::connect = sub { $connect++ unless shift->{connected}++ };
Mojo::IOLoop->timer(0.2 => sub { Mojo::IOLoop->stop });    # should be long enough
Mojo::IOLoop->start;
is $connect, 3, 'started connections, except disconnected';

File::Path::remove_tree($ENV{CONVOS_HOME});

done_testing;
