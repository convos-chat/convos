BEGIN {
  our $time = time - 10;
  *CORE::GLOBAL::time = sub {$time};
}
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

no warnings qw( once redefine );

my $core = Convos::Core->new(backend => Convos::Core::Backend::File->new);
my $user = $core->user('jhthorsen@cpan.org', {});
my $storage_file = File::Spec->catfile($ENV{CONVOS_HOME}, 'jhthorsen@cpan.org', 'user.json');
is $user->avatar,   '',                   'avatar';
is $user->email,    'jhthorsen@cpan.org', 'email';
is $user->password, '',                   'password';

is $user->load, $user, 'load';
ok !-e $storage_file, 'no storage file';
$user->avatar('whatever');
is $user->save, $user, 'save';
ok -e $storage_file, 'created storage file';
is $core->user('jhthorsen@cpan.org')->load->avatar, 'whatever', 'avatar from storage file';

is_deeply(
  $user->TO_JSON,
  {
    avatar     => 'whatever',
    email      => 'jhthorsen@cpan.org',
    path       => '/jhthorsen@cpan.org',
    registered => Mojo::Date->new($main::time)->to_datetime
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
is $core->user('jhthorsen@cpan.org')->load->password, $user->password, 'password from storage file';

done_testing;
