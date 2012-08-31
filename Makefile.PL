use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
    'Mojolicious' => '3.13',
   #'Mojo::Redis' => '0.09', # https://github.com/marcusramberg/mojo-redis
    'IRC::Utils' => '0.12',
    'Mojolicious::Plugin::UrlWith' => 0.0501;
    'Parse::IRC' => '1.18',
  },
  test      => {TESTS => 't/*.t'}
);
