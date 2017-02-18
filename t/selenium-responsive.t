use lib '.';
use t::Selenium;

my $t          = t::Selenium->selenium_init('Convos', {lazy => 1, loc => '/?isMobile=1'});
my $user       = $t->app->core->get_user("$NICK\@convos.by");
my $connection = $user->get_connection('irc-default');
my $dialog     = $connection->get_dialog('#test');

$t->wait_until(sub { $_->find_element('.convos-login') });
t::Selenium->set_window_size($t, 'iphone6');
t::Selenium->selenium_login($t);

$t->wait_until(sub { $_->find_element('.convos-main-menu [href="#chat/irc-default/#test"]') });

# hidden on small screens
$t->element_is_hidden('.convos-main-menu');
$t->live_element_exists_not('.convos-notifications.is-sidebar');
$t->live_element_exists_not('.convos-sidebar-info.is-sidebar');

my @messages = t::Helper->messages;
$connection->emit(message => $dialog, $_) for splice @messages, 0, 3;
is_at_bottom();

$connection->emit(message => $dialog, $_) for @messages;
run_for(0.5);
is_at_bottom();

#run_for(10);
#is_at_bottom();

done_testing;

sub is_at_bottom {
  my $s = $t->driver->execute_script(<<'HERE');
var el = document.querySelector(".scroll-element");
return {total: el.scrollHeight, offset: el.offsetHeight, scrolled: el.scrollTop};
HERE

  is $s->{scrolled} + $s->{offset}, $s->{total},
    "scroll: $s->{scrolled} + $s->{offset} == $s->{total}";
}

sub run_for {
  Mojo::IOLoop->timer($_[0] => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
}
