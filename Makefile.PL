use ExtUtils::MakeMaker;
use Cwd ();

open my $CPANFILE, '<', Cwd::abs_path('cpanfile') or die "cpanfile: $!";
eval <<"CPANFILE_EVAL" or die $@;
package JAIL;
sub requires { \$main::BUILD_REQUIRES{\$_[0]} = \$_[1] }
@{[<$CPANFILE>]}
1;
CPANFILE_EVAL

WriteMakefile(
  NAME => 'Convos',
  ABSTRACT_FROM => 'lib/Convos.pm',
  VERSION_FROM => 'lib/Convos.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen\@cpan.org>',
  LICENSE => 'artistic_2',
  PREREQ_PM => \%main::BUILD_REQUIRES,
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://www.opensource.org/licenses/artistic-license-2.0',
      homepage => 'http://convos.by',
      bugtracker => 'https://github.com/Nordaaker/convos/issues',
      repository => 'https://github.com/Nordaaker/convos',
    },
  },
  test => { TESTS => 't/*.t' },
  EXE_FILES => ['script/convos'],
);
 
