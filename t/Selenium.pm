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

  return $t;
}

1;
