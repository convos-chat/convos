#!perl
use lib '.';
use t::Helper;
use Mojo::JSON 'decode_json';

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

my @resources = (
  '/', '/chat', '/chat/irc-foo', '/chat/irc-foo/bar', '/help', '/register',
  '/register?email=test@example.com&exp=1594263232&token=abc',
  '/search', '/settings', '/settings/account',
);

for my $resource (@resources) {
  subtest $resource => sub {
    $t->get_ok($resource)->status_is($resource =~ /email=/ ? 410 : 200);
    my $json = decode_json($t->tx->res->text =~ m!const settings\s*=\s*([^;]+)!m ? $1 : '{}');
    is $json->{api_url}, '/api',                  'api_url';
    is $json->{contact}, 'mailto:root@localhost', 'contact';
    is $json->{load_user},      true,  'load_user';
    is $json->{open_to_public}, false, 'open_to_public';
    is $json->{organization_name}, 'Convos',              'organization_name';
    is $json->{organization_url},  'https://convos.chat', 'organization_url';
    ok $json->{base_url},          'base_url';
    ok $json->{default_connection}, 'default_connection';
    ok $json->{version},            'version';
    ok $json->{ws_url},             'ws_url';
    ok !$json->{user}, 'the user should not be part of the settings';
  };
}

done_testing;
