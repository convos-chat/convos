use utf8;
use strict;
use ExtUtils::MakeMaker;

my %wanted = map { ($_ => 1) } split /,/,
  ($ENV{CONVOS_DEPENDENCIES} || '');    # all,recommended,bot,ldap

my @PREREQS = (
  [bot         => 'DBD::SQLite',        '1.66'],                 # bot core
  [bot         => 'Hailo',              '0.75'],                 # bot hailo
  [bot         => 'Math::Calc::Parser', '1.00'],                 # bot calc
  [ldap        => 'Net::LDAP',          '0.68'],                 # auth ldap
  [recommended => 'Cpanel::JSON::XS',   '4.09'],                 # speed
  [recommended => 'EV',                 '4.00'],                 # speed
  [recommended => 'IO::Socket::Socks',  '0.64'],                 # non-blocking
  [core        => 'Crypt::Passphrase'            => '0.019'],    # password
  [core        => 'Crypt::Passphrase::Argon2'    => '0.009'],    # password
  [core        => 'Crypt::Argon2'                => '0.022'],    # password
  [core        => 'Crypt::Passphrase::Bcrypt'    => '0.008'],    # password
  [core        => 'File::HomeDir'                => '1.00'],     # core
  [core        => 'File::ReadBackwards'          => '1.06'],     # backend file
  [core        => 'Future::AsyncAwait'           => '0.66'],     # core
  [core        => 'HTTP::AcceptLanguage'         => '0.02'],     # i18n
  [core        => 'IO::Socket::SSL'              => '2.009'],    # cpanm -M ...
  [core        => 'IRC::Utils'                   => '0.12'],     # irc
  [core        => 'LinkEmbedder'                 => '1.20'],     # embed
  [core        => 'Module::Install'              => '1.10'],     # Text::MultiMarkdown
  [core        => 'Mojolicious'                  => '9.35'],     # core
  [core        => 'Mojolicious::Plugin::OpenAPI' => '5.09'],     # core
  [core        => 'Mojolicious::Plugin::Syslog'  => '0.06'],     # logging
  [core        => 'Parse::IRC'                   => '1.22'],     # irc
  [core        => 'Syntax::Keyword::Try'         => '0.29'],     # core
  [core        => 'Text::Markdown::Hoedown'      => '1.03'],     # cms
  [core        => 'Time::Piece'                  => '1.20'],     # core
  [core        => 'Unicode::UTF8'                => '0.62'],     # irc
  [core        => 'YAML::XS'                     => '0.88'],     # bot core
  [core        => 'perl'                         => '5.020'],    # core
);

my %WriteMakefileArgs = (
  NAME           => 'Convos',
  AUTHOR         => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE        => 'artistic_2',
  ABSTRACT_FROM  => 'lib/Convos.pm',
  VERSION_FROM   => 'lib/Convos.pm',
  EXE_FILES      => [qw(script/convos)],
  BUILD_REQUIRES => {},
  TEST_REQUIRES  => {'Test::Deep' => '0.11', 'Test::More' => '0.88'},
  PREREQ_PM      => {},
  META_MERGE     => {
    'dynamic_config' => 0,
    'meta-spec'      => {version => 2},
    'resources'      => {
      bugtracker => {web => 'https://github.com/convos-chat/convos/issues'},
      homepage   => 'https://github.com/convos-chat/convos',
      repository => {
        type => 'git',
        url  => 'https://github.com/convos-chat/convos.git',
        web  => 'https://github.com/convos-chat/convos',
      },
    },
    'x_contributors' =>
      ['Jan Henning Thorsen <jhthorsen@cpan.org>', 'Marcus Ramberg <marcus@convos-chat.com>'],
  },
  test => {TESTS => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
);

for (@PREREQS) {
  my ($group, $module, $version) = @$_;
  $WriteMakefileArgs{PREREQ_PM}{$module} = $version
    if $group eq 'core' || $wanted{all} || $wanted{$group};
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.63_03') }) {
  my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES};
  @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

$INC{'ExtUtils/MakeMaker.pm'} eq 'source' ? @PREREQS : WriteMakefile(%WriteMakefileArgs);
