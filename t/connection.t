use t::Helper;
use Convos::Core;

my $core       = Convos::Core->new;
my $user       = $core->user({email => 'test@example.com'});
my $connection = $user->connection({name => 'whatever', protocol => 'Irc'});

ok !$connection->dialog('#foo')->is_private, 'channel';
ok $connection->dialog('marcus')->is_private, 'person';
ok !$connection->{dialog}{'#foo'}, 'no dialog on get';

my $dialog = $connection->dialog('#foo' => {});
is $dialog->n_users, 0, 'dialog->n_users';
ok $connection->{dialogs}{'#foo'}, 'dialog on create/update';

$connection = Convos::Core::Connection->new({});
for my $method (qw( rooms join_dialog connect send topic)) {
  my $err;
  eval {
    $connection->$method(sub { $err = $_[1] });
  };
  is $err, qq(Method "$method" not implemented.), $method;
}

done_testing;
