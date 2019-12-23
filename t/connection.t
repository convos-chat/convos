#!perl
use lib '.';
use t::Helper;
use Convos::Core;

my $core       = Convos::Core->new;
my $user       = $core->user({email => 'test@example.com'});
my $connection = $user->connection({name => 'whatever', protocol => 'Irc'});

ok !$connection->dialog({name => '#foo'})->is_private, 'channel';
ok $connection->dialog({name => 'marcus'})->is_private, 'person';
ok !$connection->{dialog}{'#foo'}, 'no dialog on get';

my $dialog = $connection->get_dialog('#foo');
ok $connection->{dialogs}{'#foo'}, 'dialog on create/update';

$connection = Convos::Core::Connection->new({});
$connection->disconnect_p->$wait_success('disconnect_p');

eval { $connection->send_p };
like $@, qr(^Method "send_p" not implemented), 'send_p';

done_testing;
