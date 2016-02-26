use t::Helper;
use Convos::Core;

my $core       = Convos::Core->new;
my $user       = $core->user({email => 'test@example.com'});
my $connection = $user->connection({name => 'whatever', protocol => 'Irc'});

ok !$connection->dialogue('#foo')->is_private, 'channel';
ok $connection->dialogue('marcus')->is_private, 'person';
ok !$connection->{dialogue}{'#foo'}, 'no dialogue on get';

my $dialogue = $connection->dialogue('#foo' => {});
is $dialogue->n_users, 0, 'dialogue->n_users';
ok $connection->{dialogues}{'#foo'}, 'dialogue on create/update';

$connection = Convos::Core::Connection->new({});
for my $method (qw( rooms join_dialogue connect send topic)) {
  my $err;
  eval {
    $connection->$method(sub { $err = $_[1] });
  };
  is $err, qq(Method "$method" not implemented.), $method;
}

done_testing;
