use Mojo::Base -strict;
use Convos::Model;
use Test::More;

local $ENV{CONVOS_SHARE_DIR} = 'convos-test-model-user-share-dir';

my $model = Convos::Model->new;
eval { $model->user('') };
like $@, qr{Usage.*email}, 'user() require email';

my $user = $model->user('jhthorsen@cpan.org', avatar => 'whatever');
my $settings_file = File::Spec->catfile($ENV{CONVOS_SHARE_DIR}, 'jhthorsen@cpan.org', 'settings.json');
is $user->avatar,   'whatever',                                                   'avatar';
is $user->email,    'jhthorsen@cpan.org',                                         'email';
like $user->home,   qr{convos-test-model-user-share-dir\W+jhthorsen\@cpan\.org$}, 'home';
is $user->password, '',                                                           'password';

is $user->load, $user, 'load';
ok !-e $settings_file, 'no settings.json';
is $user->save, $user, 'save';
ok -e $settings_file, 'created settings.json';
is $model->user('jhthorsen@cpan.org')->load->avatar, 'whatever', 'avatar from settings.json';

is_deeply($user->TO_JSON, {avatar => 'whatever', email => 'jhthorsen@cpan.org'}, 'TO_JSON');

eval { $user->set_password('') };
like $@, qr{Usage:.*plain}, 'set_password() require plain string';
ok !$user->password, 'no password';
is $user->set_password('s3cret'), $user, 'set_password does not care about password quality';
ok $user->password, 'password';

ok !$user->validate_password('s3crett'), 'invalid password';
ok $user->validate_password('s3cret'), 'validate_password';

$user->save;
is $model->user('jhthorsen@cpan.org')->load->password, $user->password, 'password from settings.json';

File::Path::remove_tree($ENV{CONVOS_SHARE_DIR});
done_testing;
