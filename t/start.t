use Mojo::Base -strict;
use Test::More;

$ENV{CONVOS_SHARE_DIR}     = 'convos-test-model-connection-start';
$ENV{CONVOS_CONNECT_TIMER} = 0.01;

no warnings qw( once redefine );
require Convos::Model;

my $model   = Convos::Model->new_with_backend('File');
my $connect = 0;

{
  my $user = $model->user('jhthorsen@cpan.org')->save;
  $user->connection(IRC => 'localhost')->tap(sub { shift->url->parse('irc://localhost') })->save;
}

{
  my $user = $model->user('mramberg@cpan.org')->save;
  $user->connection(IRC => 'freenode')->tap(sub  { shift->url->parse('irc://chat.freenode.net:6697') })->save;
  $user->connection(IRC => 'localhost')->tap(sub { shift->url->parse('irc://127.0.0.1') })->save;
  $user->connection(IRC => 'perlorg')->tap(sub   { shift->url->parse('irc://irc.perl.org') })->save;
}

# restart the whole object
$model = Convos::Model->new_with_backend('File');
$model->start;
*Mojo::IRC::UA::connect = sub { $connect++; Mojo::IOLoop->stop };
Mojo::IOLoop->timer(2 => sub { $connect = 20 });
Mojo::IOLoop->one_tick until $connect >= 4;
is $connect, 4, 'started connections';

File::Path::remove_tree($ENV{CONVOS_SHARE_DIR});

done_testing;
