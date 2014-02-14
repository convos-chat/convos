use t::Helper;

$t->get_ok('/');
like $t->app->secrets->[0], qr/^[a-f0-9]{32}$/, 'generated app secret';
done_testing;
