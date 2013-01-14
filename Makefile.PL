use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
    'Mojolicious' => '3.13',

    #'Mojo::Redis' => '0.09', # https://github.com/marcusramberg/mojo-redis
    'IRC::Utils'                   => '0.12',
    'Mojo::Redis'                  => '0.9902',
    'Mojolicious::Plugin::UrlWith' => 0.0501,
    'Parse::IRC'                   => '1.18',
    'List::MoreUtils'              => 0,
    'File::Slurp'                  => 0,
    'Time::Piece'                  => 1.20,
    'Unicode::UTF8'                => 0,
  },
  test => {TESTS => 't/*.t'}
);
