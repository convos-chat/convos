use ExtUtils::MakeMaker;
WriteMakefile(
  VERSION_FROM => 'lib/WebIrc.pm',
  PREREQ_PM => {
    'File::Slurp'     => 0,
    'IRC::Utils'      => 0.12,
    'List::MoreUtils' => 0,
    'Mojo::IRC'       => 0.03,
    'Mojolicious'     => 4.30,
    'Mojo::Redis'     => 0.9916,
    'Parse::IRC'      => 1.18,
    'Time::Piece'     => 1.20,
    'Unicode::UTF8'   => 0.58,
    'DateTime'        => 0,
  },
  test => {
    TESTS => 't/*.t',
  }
);
