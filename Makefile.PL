use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
    'IO::Async::Loop::Mojo' => '0.02',
    'Mojolicious' => '3.13',
   #'Mojo::Redis' => '0.09', # https://github.com/marcusramberg/mojo-redis
    'Net::Async::IRC' => '0.05',
  },
  test      => {TESTS => 't/*.t'}
);
