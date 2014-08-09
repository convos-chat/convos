BEGIN { $ENV{CONVOS_INVITE_CODE} = 'superdupersecret'; }
use t::Helper;

my $form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar',};

$t->get_ok('/register')->status_is(400)->text_is('.register > h2', 'Register or')->content_like(qr{Please ask the Convos administrator});
$t->post_ok('/register' => form => $form)->status_is(400)->content_like(qr{Please ask the Convos administrator});
$t->post_ok('/register/invalid_invite_code' => form => $form)->status_is(400)->content_like(qr{Invalid invite code});
$t->post_ok('/register/superdupersecret' => form => $form)->status_is(302);

done_testing;
