BEGIN {
  $ENV{CONVOS_INVITE_CODE} = 'superdupersecret';
}
use t::Helper;

my $form;

{
  local $TODO = 'Will be fixed in #84';
  $form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar',};

  $t->get_ok('/register')->status_is(200)->text_is('.alert h2', 'Invite only installation.');
}

{
  $t->post_ok('/register' => form => $form)->status_is(400)->text_is('.alert h2', 'Invite only installation.');
}

{
  $t->post_ok('/register/superdupersecret' => form => $form)->status_is(302);
}

done_testing;
