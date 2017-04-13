package t::Helper;
use Mojo::Base -strict;

use Convos;
use File::Basename 'basename';
use File::Path ();
use FindBin;
use Mojo::Loader 'data_section';
use Mojo::Util;

our $CONVOS_HOME;
our $TEST_MEMORY_CYCLE = eval 'require Test::Memory::Cycle;1';

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

sub messages {
  my $class = shift;
  my $ts    = shift || 1433817540;    # 2015-06-09T04:39:00
  my $int   = shift || 2;
  my @messages;

  $ts = Time::Piece->strptime($ts, '%Y-%m-%dT%H:%M:%S') if $ts =~ /T/;

  for (split /\n/, data_section qw(t::Helper messages.json)) {
    my ($from, $msg) = split / /, $_, 2;
    my $event = $from =~ s/^-// ? 'notice' : $from =~ s/^\*// ? 'action' : 'private';
    $ts += $int;
    push @messages,
      {
      from      => $from,
      highlight => $msg =~ /superman/i ? Mojo::JSON->true : Mojo::JSON->false,
      message   => $msg,
      ts        => $ts,
      type      => $event,
      };
  }

  return @messages;
}

sub t {
  require Test::Mojo;
  Test::Mojo->new($_[1] || 'Convos');
}

sub import {
  my $class  = shift;
  my $caller = shift || caller;
  my $script = basename $0;

  eval <<"HERE" or die $@;
package $caller;
use Test::More;
use Test::Deep;
use Mojo::JSON qw(false true);
1;
HERE

  $_->import for qw(strict warnings utf8);
  feature->import(':5.10');

  $script =~ s/\W/-/g;
  $ENV{CONVOS_HOME} = $CONVOS_HOME
    = File::Spec->catdir($FindBin::Bin, File::Spec->updir, "local", "test-$script");
  File::Path::remove_tree($CONVOS_HOME) if -d $CONVOS_HOME;

  Mojo::Util::monkey_patch($caller => memory_cycle_ok => $TEST_MEMORY_CYCLE
    ? \&Test::Memory::Cycle::memory_cycle_ok
    : sub { Test::More::diag('Test::Memory::Cycle is not available') });
}

END {
  # $ENV{CONVOS_HOME} might have been changed to a directory which should not be removed
  if (!$ENV{CONVOS_DEBUG} and $CONVOS_HOME and -d $CONVOS_HOME) {
    Test::More::note("remove_tree $CONVOS_HOME");
    File::Path::remove_tree($CONVOS_HOME);
  }
}

BEGIN {

  package NoForkCall;

  sub run {
    my ($self, $fork, $cb) = @_;
    $self->$cb('', $fork->());
  }
}

1;

__DATA__
@@ messages.json
Supergirl For a lightweight VPN alternative, have a look at ssh + netcat-openbsd for
Supergirl To manage Apache virtualhosts use "a2ensite" to enable and "a2dissite" to
Supergirl The column allows you to format output neatly. ex: 'mount | column -t' will
*jhthorsen To manage Apache modules use "a2enmod" to enable and "a2dismod" to disable.
Supergirl To manage Apache virtualhosts use "a2ensite" to enable and "a2dissite" to
jhthorsen Unsure if AppArmor might be causing an issue? Don't disable it, use the
Supergirl You can use the text-based web browser w3m to browse the Internet in your
mr22 If you know you typed a command or password wrong, you can use ctrl + u to
mr22 Reach the end-of-line with ctrl-e and the beginning of line with ctrl-a.
-batman Did you know that you can get useful notifications displayed at the bottom
-batman If you want to download a file from a URL via the console, you can use the
*batman The powernap package allows you to suspend servers which are not being used,
batman Use "iotop" for measuring hard disk I/O (current read/write) usage per
batman The Ubuntu Server Team is an open community always looking for feedback and
batman You can contact the Ubuntu Server team on IRC using chat.freenode.net in
batman Having trouble with DNS records? dig, ping and named-checkzone are great
Supergirl To restrict ssh logins to certain commands, have a look at the ForceCommand
Supergirl An easy way to see what SUPERMAN own
Supergirl Use "iftop" to monitor current network activity connections per host.
superman To find a package which name or description contains a keyword use:
superman You can contact the Ubuntu Server team on IRC using chat.freenode.net in
*superman Tired of repeatedly pressing 'y' through some shell process (e.g. fsck)? Try
superman Use "top" to get a view of your server's performance such as processor,
superman If you need to compile a piece of software, you may need to install the
superman You can edit your network configuration in /etc/network/interfaces and
superman The free command tells you the status of your memory and swap, how much you
superman Tired of repeatedly pressing 'y' through some shell process (e.g. fsck)? Try
-superman An easy way to see what processes own which network connections: 'sudo
-superman Successive commands usually process the same argument. 'Alt-.' inserts the
-Supergirl For a lightweight VPN alternative, have a look at ssh + netcat-openbsd for
-Supergirl 'screen' can create multiple "windows" which you can detach and re-attach
-Supergirl To find in which file an event has been logged in use 'ls -ltr /var/log |
Supergirl Reach the end-of-line with ctrl-e and the beginning of line with ctrl-a.
Supergirl To find in which file an event has been logged in use 'ls -ltr /var/log |
Supergirl Use "tail -f /var/log/some.log" to see new lines added to a log instantly in
Supergirl If you want to download a file from a URL via the console, you can use the
batman The powernap package allows you to suspend servers which are not being used,
batman The powernap package allows you to suspend servers which are not being used,
batman To restrict ssh logins to certain commands, have a look at the ForceCommand
*batman You can add "| grep word" to search for a word in the output of a command.
*batman If the empty file ~/.hushlogin exists on the server, login to the server
batman Did you know that releases of Ubuntu labeled LTS are maintained for 5 years
Supergirl Did you know that releases of Ubuntu labeled LTS are maintained for 5 years
Supergirl If you want to download a file from a URL via the console, you can use the
Supergirl Typing 'dmesg | tail' after you plug in usb storage will give you its
Supergirl Keep your servers time in sync, use the ntpd package.
Supergirl To manage Apache virtualhosts use "a2ensite" to enable and "a2dissite" to
Supergirl Documentation and other resources pointers for Ubuntu Server Edition are
Supergirl Edit the command line with cut and paste: ctrl-k for cut, and ctrl-y for
-mr_fantastic To have grep return the string you are looking for without checking for
-mr_fantastic If you need to perform a command a second time on a different file, you can
-mr_fantastic Use the 'watch' command to repeat the same command a regular interval and
-mr_fantastic If you know you typed a command or password wrong, you can use ctrl + u to
-mr_fantastic Edit the command line with cut and paste: ctrl-k for cut, and ctrl-y for
Supergirl 'screen' can create multiple "windows" which you can detach and re-attach
mr22 Did you know that you can get useful notifications displayed at the bottom
mr22 'etckeeper' allows you to save changes you make to /etc in a bazaar
mr22 [convos] jhthorsen pushed 3 new commits to master: https://git.io/vD9nM
mr22 If you know you typed a command or password wrong, you can use ctrl + u to
mr22 For a lightweight VPN alternative, have a look at ssh + netcat-openbsd for
mr22 Keep your servers time in sync, use the ntpd package.
mr22 To deactivate a service at boot, for example, apache2: 'sudo update-rc.d -f
mr22 Save time starting to type a command or file name, then press tab to
mr22 Need a little refresh on networking concept? Take a look at the networking
-mr22 To manage Apache virtualhosts use "a2ensite" to enable and "a2dissite" to
-mr22 If you want to download a file from a URL via the console, you can use the
-mr22 Did you know that you can get useful notifications displayed at the bottom
-mr22 If you executed a command and neglected to use sudo, you can execute "sudo
mr22 Two packages are recommended to perform backups of your clients and servers
mr22 Use the 'watch' command to repeat the same command a regular interval and
mr22 Use lsof to find out which process has open handles for a file. 'lsof +D
mr22 The column allows you to format output neatly. ex: 'mount | column -t' will
mr22 If you executed a command and neglected to use sudo, you can execute "sudo
mr22 You can use the text-based web browser w3m to browse the Internet in your
mr22 The powernap package allows you to suspend servers which are not being used,
mr22 [convos] jhthorsen pushed 1 new commit to master: https://git.io/vDQJ7
mr22 [mojo-irc] jhthorsen pushed https://github.com/Nordaaker/convos/commit/867b89321eb6f4131a394757a2a1017401533079
mr22 http://convos.by/doc/
mr22 A for loop in bash syntax: 'for i in *; do echo $i ; done'.
*mr22 Use "iotop" for measuring hard disk I/O (current read/write) usage per
mr22 [convos] jhthorsen pushed 1 new commit to master: https://git.io/vDF6H
