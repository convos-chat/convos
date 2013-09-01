use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
    'Mojolicious' => '3.13',

    #'Mojo::Redis' => '0.09', # https://github.com/marcusramberg/mojo-redis
    'File::Slurp'                  => 0,
    'IRC::Utils'                   => '0.12',
    'List::MoreUtils'              => 0,
    'Mojo::IRC'                    => 0.01,
    'Mojo::Redis'                  => '0.9913',
    'Parse::IRC'                   => '1.18',
    'Time::Piece'                  => 1.20,
    'Unicode::UTF8'                => 0.58,
  },
  test => {TESTS => 't/*.t'}
);
