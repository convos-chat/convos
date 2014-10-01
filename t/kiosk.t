BEGIN { $ENV{CONVOS_KIOSK_SERVERS} = 'chat.freenode.org|irc.perl.org' }
use t::Helper;
my ($login, @ctrl);

$t->app->core->start;

{
  no warnings 'redefine';
  *Convos::Core::ctrl_start = sub { shift; push @ctrl, @_ };
  my $generate_login_name = \&Convos::Core::Util::generate_login_name;
  *Convos::Core::Util::generate_login_name = sub { $login = $generate_login_name->(@_) };
}

$t->get_ok('/kiosk')->status_is(200)->text_is('h2', 'Kiosk Mode')->element_exists_not('p.error')
  ->content_like(qr{&lt;iframe src="http://}, 'kiosk instructions');

$t->get_ok('/kiosk?server=chat.invalid&channel=%23foo')->status_is(200)->text_is('h2', 'Kiosk Mode')
  ->text_is('p.error', 'Invalid server name chat.invalid.');
$t->get_ok('/kiosk?server=chat.freenode.org&channel=convos')->status_is(200)->text_is('h2', 'Kiosk Mode')
  ->text_is('p.error', 'Invalid channel name convos.');

$t->get_ok('/kiosk?server=chat.freenode.org&channel=%23convos')->status_is(302)->header_is(Location => '/freenode');

is_deeply \@ctrl, [$login, 'freenode'], 'start connection';

$t->get_ok('/logout')->status_is(302)->header_is(Location => '/');

done_testing;
