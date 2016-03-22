package t::Helper;
use Mojo::Base -base;
use Mojo::Util;
use Convos;
use File::Path ();

our $CONVOS_HOME;

$ENV{CONVOS_SECRETS} = 'not-very-secret';
$ENV{MOJO_LOG_LEVEL} = 'error' unless $ENV{HARNESS_IS_VERBOSE};

sub connect_to_irc {
  my ($class, $connection) = @_;
  my $t      = Test::Mojo::IRC->new;
  my $server = $t->start_server;
  $connection->url->parse("irc://$server");
  $connection->connect(sub { Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  return $t;
}

sub t {
  require Test::Mojo;
  Test::Mojo->new('Convos');
}

sub import {
  my $class  = shift;
  my $caller = caller;
  my $script = $0;

  eval "package $caller;use Mojo::Base -base;use Test::More;use Test::Deep;1" or die $@;
  strict->import;
  warnings->import;

  $script =~ s/\W/-/g;
  $ENV{CONVOS_HOME} = $CONVOS_HOME = File::Spec->catdir("local", "test-$script");
  Mojo::Util::monkey_patch($caller => diag => $ENV{HARNESS_IS_VERBOSE} ? \&Test::More::diag : sub { });
  File::Path::remove_tree($CONVOS_HOME) if -d $CONVOS_HOME;
}

END {
  # $ENV{CONVOS_HOME} might have been changed to a directory which should not be removed
  if (!$ENV{CONVOS_DEBUG} and $CONVOS_HOME and -d $CONVOS_HOME) {
    Test::More::diag("remove_tree $CONVOS_HOME") if $ENV{HARNESS_IS_VERBOSE};
    File::Path::remove_tree($CONVOS_HOME);
  }
}

1;
