#!perl
BEGIN {
  our $time = time - 10;
  *CORE::GLOBAL::time = sub {$time};
}
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

no warnings qw(once redefine);

my $core = Convos::Core->new(backend => 'Convos::Core::Backend::File');

# test trim and lower case
my $user          = $core->user({email => ' JhtHorsen@cpan.org  '});
my $settings_file = File::Spec->catfile($ENV{CONVOS_HOME}, 'jhthorsen@cpan.org', 'user.json');
is $user->email, 'jhthorsen@cpan.org', 'email';
is $user->password, '', 'password';

ok !-e $settings_file, 'no storage file';
is $user->save, $user, 'save';
ok -e $settings_file, 'created storage file';

is_deeply(
  $user->TO_JSON,
  {
    email              => 'jhthorsen@cpan.org',
    highlight_keywords => [],
    registered         => Mojo::Date->new($main::time)->to_datetime,
    roles              => [],
    unread             => 0
  },
  'TO_JSON'
);

eval { $user->set_password('') };
like $@, qr{Usage:.*plain}, 'set_password() require plain string';
ok !$user->password, 'no password';
is $user->set_password('s3cret'), $user, 'set_password does not care about password quality';
ok $user->password, 'password';

ok !$user->validate_password('s3crett'), 'invalid password';
ok $user->validate_password('s3cret'), 'validate_password';

$user->save;
is $core->get_user('jhthorsen@cpan.org')->password, $user->password, 'password from storage file';


$user->{unread} = 3;
$user->save;
is $core->get_user('jhthorsen@cpan.org')->unread, 3, 'Unseen is persisted correctly';

done_testing;
