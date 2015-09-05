package t::Helper;
use Mojo::Base -base;
use Convos;
use File::Path ();

our $CONVOS_HOME;

sub t {
  require Test::Mojo;
  Test::Mojo->new('Convos');
}

sub import {
  my $class  = shift;
  my $caller = caller;
  my $script = $0;

  eval "package $caller;use Mojo::Base -base;use Test::More;use Test::Deep;1" or die $@;

  $script =~ s/\W/-/g;
  $CONVOS_HOME = File::Spec->catdir("local", "test-$script");
  $ENV{CONVOS_HOME} = $CONVOS_HOME;
}

END {
  # $ENV{CONVOS_HOME} might have been changed to a directory which should not be removed
  File::Path::remove_tree($CONVOS_HOME) if !$ENV{TEST_KEEP_HOME} and $CONVOS_HOME and -d $CONVOS_HOME;
}

1;
