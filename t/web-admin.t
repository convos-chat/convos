#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

note 'default settings';
$t->get_ok('/')->status_is(200)->element_exists_not('h1 .subtitle');

note 'need to log in first';
$t->post_ok('/api/settings', json => {open_to_public => true})->status_is(401);

note 'add admin user';
$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

note 'get default settings';
$t->get_ok('/api/settings')->status_is(200)->json_hasnt('/local_secret')
  ->json_hasnt('/session_secrets')->json_is('/contact', 'mailto:root@localhost')
  ->json_is('/default_connection', 'irc://chat.freenode.net:6697/%23convos')
  ->json_is('/forced_connection',  false)->json_is('/open_to_public', false)
  ->json_is('/organization_name',  'Convos')->json_is('/organization_url', 'https://convos.by');

note 'input validation';
$t->post_ok(
  '/api/settings',
  json => {
    contact            => 'jhthorsen@cpan.org',
    default_connection => 'localhost:6667',
    organization_url   => 'convos.by',
  }
)->status_is(400)->json_is('/errors/0/message', 'Contact URL need to start with "mailto:".')
  ->json_is('/errors/1/message', 'Connection URL require a scheme and host.')
  ->json_is('/errors/2/message', 'Organization URL require a scheme and host.');

note 'change only one setting';
$t->post_ok('/api/settings', json => {open_to_public => true})->status_is(200)
  ->json_hasnt('/local_secret')->json_hasnt('/session_secrets')
  ->json_is('/default_connection', 'irc://chat.freenode.net:6697/%23convos')
  ->json_is('/open_to_public',     true);

note 'change all settings and also reject some';
my $settings    = $t->app->core->settings;
my $before_post = $settings->TO_JSON(1);
$t->post_ok(
  '/api/settings',
  json => {
    contact            => 'mailto:jhthorsen@cpan.org',
    default_connection => 'irc://chat.freenode.net:6697/%23mojo',
    forced_connection  => true,
    local_secret       => 's3cret',
    max_message_size   => 10,
    open_to_public     => true,
    organization_name  => 'Superheroes',
    organization_url   => 'https://metacpan.org',
    session_secrets    => ['s3cret'],
  }
)->status_is(200)->json_is('/contact' => 'mailto:jhthorsen@cpan.org')
  ->json_is('/default_connection' => 'irc://chat.freenode.net:6697/%23mojo')
  ->json_is('/forced_connection'  => true)->json_is('/local_secret' => undef)
  ->json_is('/max_message_size'   => 10)->json_is('/open_to_public' => true)
  ->json_is('/organization_name'  => 'Superheroes')
  ->json_is('/organization_url'   => 'https://metacpan.org')->json_is('/session_secrets' => undef);

$t->get_ok('/')->status_is(200)->element_exists('h1 .subtitle')
  ->element_exists('h1 .subtitle[href="https://metacpan.org"]')
  ->text_is('h1 .subtitle', 'for Superheroes');

is $settings->local_secret,    $before_post->{local_secret},    'local_secret was not changed';
is $settings->session_secrets, $before_post->{session_secrets}, 'session_secrets was not changed';

note 'test clearing config';
$t->post_ok('/api/settings', json => {organization_url => ''})->status_is(200);
$t->get_ok('/')->status_is(200)->element_exists('h1 .subtitle')
  ->element_exists_not('h1 .subtitle[href="https://metacpan.org"]')
  ->text_is('h1 .subtitle', 'for Superheroes');

note 'only admins change settings';
$t->app->core->get_user('superman@example.com')->role(take => 'admin');
$t->post_ok('/api/settings', json => {open_to_public => true})->status_is(401);

done_testing;
