use t::Helper;

$ENV{CONVOS_BACKEND}              = 'Convos::Core::Backend';
$ENV{CONVOS_DISABLE_REGISTRATION} = 1;
my $t = t::Helper->t;

$t->post_ok('/api/user/register', json => {email => 'superman@cpan.org', password => 'xyz'})
  ->status_is(400)->json_is('/errors/0', {message => 'Registration is closed.', path => '/'});

done_testing;
