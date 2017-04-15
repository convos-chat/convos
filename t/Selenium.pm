package t::Selenium;
use Test::More ();
use Mojo::Base 't::Helper';
BEGIN { $ENV{TEST_SELENIUM} or Test::More::plan(skip_all => 'TEST_SELENIUM=1') }
use Test::Mojo::WithRoles 'Selenium';
use Sys::Hostname 'hostname';

$ENV{MOJO_SELENIUM_DRIVER} ||= 'Selenium::Chrome';

sub browser_log {
  my ($class, $t) = @_;
  my $log = $t->driver->execute_script('return H');
  $t->driver->execute_script('H=[];');
  return $log if defined wantarray;
  Test::More::note($_) for @$log;
}

sub desktop_notification_is {
  my ($class, $t, $expected) = @_;
  my $got   = $t->driver->execute_script('return N.pop()');
  my $descr = $expected ? join ' ', @$expected : 'none';
  my $ok    = Test::Deep::cmp_deeply($got, $expected, substr "Notification: $descr", 0, 40);
  Test::More::diag(join ' ', @{$got || ['no notification']}) unless $ok;
  return $ok;
}

sub email {
  $main::NICK ||= 't' . substr Mojo::Util::md5_sum(join ':', hostname(), $<, $0), 0, 7;
  return sprintf '%s@convos.by', $main::NICK;
}

sub run_for {
  Mojo::IOLoop->timer($_[1] => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
}

sub selenium_init {
  my ($class, $app, $args) = @_;
  my $t = Test::Mojo::WithRoles->new($app || 'Convos');

  $t->setup_or_skip_all;
  $t->navigate_ok($args->{loc} || '/?_assetpack_reload=false&debug=info,user,watch,ws');
  $t->driver->execute_script('H=[];console.log=function(){H.push(H.join.call(arguments," "))}');
  $t->driver->execute_script('N=[];Notification.simple=function(t,b,i){N.push([t,b])}');
  $t->driver->execute_script('window.Notification.simple.history=[]');
  $class->set_window_size($t, 'desktop');

  if ($args->{lazy}) {
    my $user = $t->app->core->user({email => $class->email})->set_password('s3cret')->save;
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
  $t->send_keys_ok('#form_login_email',    [$class->email, \'tab']);
  $t->send_keys_ok('#form_login_password', ['s3cret',      \'enter']);
}

sub set_window_size {
  my ($class, $t, $size) = @_;
  my %SIZES = (desktop => [1024, 768], iphone6 => [375, 667]);
  $t->set_window_size($SIZES{$size});
}

sub import {
  my $caller = caller;
  my $class = shift->SUPER::import($caller, @_);
  no warnings 'redefine';
  *main::NICK = \my $nick;
}

1;
