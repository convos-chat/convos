#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND}     = 'Convos::Core::Backend';
$ENV{CONVOS_INVITE_CODE} = 's3cret';
my $t = t::Helper->t;
my %user = (email => 'superman@example.com', password => 's3cret');

for my $code ('', 'invalid') {
  $t->post_ok('/api/user/register', json => {invite_code => $code, %user})->status_is(400)
    ->json_is('/errors/0/message', 'Invalid invite code.');
}

$user{invite_code} = $ENV{CONVOS_INVITE_CODE};
$t->post_ok('/api/user/register', json => {%user})->status_is(200)
  ->json_is('/email', 'superman@example.com')->json_like('/registered', qr/^[\d-]+T[\d:]+Z$/);

done_testing;
