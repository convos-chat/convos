#!/usr/bin/env perl
use Mojo::Base -strict;
use Module::CPANfile;
use Data::Dumper;

$Data::Dumper::Indent   = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse    = 1;

my $prereqs        = Module::CPANfile->load->prereqs;
my $BUILD_REQUIRES = Dumper($prereqs->as_string_hash->{runtime}{requires});
my $PREREQ_PM      = Dumper({});

for ($BUILD_REQUIRES, $PREREQ_PM) {
  chomp;
  s/\n/\n  /g;
}

{
  open my $MANIFEST_SKIP, '>', 'MANIFEST.SKIP' or die $!;
  print $MANIFEST_SKIP <<'  MANIFEST_SKIP';
.swp
~$
.DS_Store
.gitignore
.perltidyrc
.sass-cache
.pid
^.git
.vimrc
^convos.production.conf
^convos.development.conf
^cover_db
^docs
^log
^local
^MANIFEST
^MYMETA.*
^Makefile$
^README.pod
^script/cpanify
^script/dev-mode
^script/flush.pl
^script/parse-irc-line.pl
^public
^templates
^vendor
^Convos-
^.travis
  MANIFEST_SKIP
}

system 'rsync -va convos.conf templates public lib/Convos/';
system 'cp convos.conf convos.testing.conf lib/Convos/';
system 'perl Makefile.PL';
system 'perldoc -tT lib/Convos.pm > README';
system 'make manifest';
system 'make dist';
system "rm $_"               for qw( README Makefile MANIFEST* );
system "rm -r lib/Convos/$_" for qw( convos.conf convos.testing.conf templates public );
