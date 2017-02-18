package t::Selenium;
use Test::More ();
use Mojo::Base 't::Helper';
BEGIN { $ENV{TEST_SELENIUM} or Test::More::plan(skip_all => 'TEST_SELENIUM=1') }
use Test::Mojo::WithRoles 'Selenium';

$ENV{MOJO_SELENIUM_DRIVER} ||= 'Selenium::Chrome';

sub selenium_init {
  my ($class, $app, $args) = @_;
  my $t = Test::Mojo::WithRoles->new($app || 'Convos');

  $t->setup_or_skip_all;
  $t->set_window_size([1024, 480])->navigate_ok('/');

  if ($args->{lazy}) {
    my $user = $t->app->core->user({email => "t$$\@convos.by"})->set_password('s3cret')->save;
    my $connection = $user->connection({name => 'default', protocol => 'irc'});
    $connection->url("irc://$ENV{CONVOS_DEFAULT_SERVER}") if $ENV{CONVOS_DEFAULT_SERVER};
    $connection->dialog({name => '#test'});
    $connection->save;
    $t->app->core->connect($connection) if $args->{connect};
  }

  if ($args->{login}) {
    $class->selenium_login($t);
  }

  return $t;
}

sub selenium_login {
  my ($class, $t) = @_;

  $t->wait_until(sub { $_->find_element('.convos-login') });
  $t->send_keys_ok('#form_login_email',    ["t$$\@convos.by", \'tab']);
  $t->send_keys_ok('#form_login_password', ['s3cret',         \'enter']);
}

1;
