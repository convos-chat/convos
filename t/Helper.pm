package t::Helper;
use Mojo::Base -strict;

use Convos;
use File::Basename 'basename';
use File::Path ();
use FindBin;
use Mojo::IOLoop;
use Mojo::Loader 'data_section';
use Mojo::URL;
use Mojo::Util 'term_escape';

our ($CONVOS_HOME, $IRC_SERVER);

$ENV{CONVOS_SECRETS} = 'not-very-secret';
$ENV{MOJO_LOG_LEVEL} = 'error' unless $ENV{HARNESS_IS_VERBOSE};

sub irc_server_connect {
  my ($class, $connection) = @_;

  return +($IRC_SERVER, $connection->url($IRC_SERVER->{connect_url}->clone)->connect)[0]
    if $IRC_SERVER;

  my $port = Mojo::IOLoop::Server->generate_port;
  my $url  = Mojo::URL->new->host('127.0.0.1')->port($port)->scheme('irc');
  $url->query->param(tls => 0);

  Mojo::IOLoop->server({address => $url->host, port => $url->port}, \&_on_irc_server_connect);
  $IRC_SERVER = Mojo::EventEmitter->new(connect_url => $url);
  return $class->irc_server_connect($connection);
}

sub irc_server_messages {
  my ($class, @rules) = @_;
  my $p  = 0;
  my $cb = $IRC_SERVER->on(message => sub { $class->_on_irc_server_message(\@rules, \$p, @_) });

  while ($p < @rules) {
    $class->_on_irc_server_message(\@rules, \$p, $IRC_SERVER, '') if $rules[$p] eq 'from_server';
    Mojo::IOLoop->one_tick;
  }

  $IRC_SERVER->unsubscribe(message => $cb);
}

sub subprocess_in_main_process {
  require Mojo::IOLoop::Subprocess;
  Mojo::Util::monkey_patch(
    'Mojo::IOLoop::Subprocess' => run => sub {
      my ($subprocess, $child, $parent) = @_;
      my @res = eval { $subprocess->$child };
      $subprocess->tap($parent, $@, @res);
    }
  );
}

sub messages {
  my $class = shift;
  my $ts    = shift || 1433817540;    # 2015-06-09T04:39:00
  my $int   = shift || 2;
  my @messages;

  $ts = Time::Piece->strptime($ts, '%Y-%m-%dT%H:%M:%S') if $ts =~ /T/;

  for (split /\n/, data_section qw(t::Helper messages.txt)) {
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

sub wait_reject {
  my ($p, $err, $desc) = (shift, shift, @_ % 2 ? pop : 'promise rejected');
  my $got;
  __PACKAGE__->irc_server_messages(@_) if @_;
  $p->then(sub { }, sub { $got = shift // ''; })->wait;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is($got, $err, $desc);
  return $p;
}

sub wait_success {
  my ($p,   $desc) = (shift, @_ % 2 ? pop : 'promise resolved');
  my ($err, @res)  = (undef);
  __PACKAGE__->irc_server_messages(@_) if @_;
  $p->then(sub { @res = @_ }, sub { $err = shift // ''; })->wait;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is($err, undef, $desc);
  Test::More::ok(0, 'invalid number of elements in response')
    or Test::More::diag(Mojo::Util::dumper(\@res))
    if @res > 1;
  return $res[0];
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
  no strict 'refs';
  my $wait_reject  = \&wait_reject;
  my $wait_success = \&wait_success;
  *{"$caller\::wait_reject"}  = \$wait_reject;
  *{"$caller\::wait_success"} = \$wait_success;
}

END {
  # $ENV{CONVOS_HOME} might have been changed to a directory which should not be removed
  if (!$ENV{CONVOS_DEBUG} and $CONVOS_HOME and -d $CONVOS_HOME) {
    Test::More::note("remove_tree $CONVOS_HOME");
    File::Path::remove_tree($CONVOS_HOME);
  }
}

sub _on_irc_server_connect {
  my ($ioloop, $stream) = @_;
  my $concat_buf = '';

  $stream->timeout(0);
  $stream->on(
    read => sub {
      $concat_buf .= $_[1];
      $IRC_SERVER->emit(message => $1) while $concat_buf =~ s/^([^\015\012]+)[\015\012]//m;
    }
  );

  $IRC_SERVER->on(close_stream => sub { $stream->close });
  $IRC_SERVER->on(write        => sub { _stream_write($stream, $_[1]) });
  $IRC_SERVER->emit(write => data_section qw(t::Helper start.irc));
}

sub _on_irc_server_message {
  my ($class, $rules, $pos, $server, $incoming) = @_;

  my ($re, $response) = ($rules->[$$pos], $rules->[$$pos + 1]);
  return unless $response;

  my $next = $$pos + 2;
  while (UNIVERSAL::isa($rules->[$next], 'Convos::Core::Connection')) {
    my $event_name = $rules->[$next + 1];
    $rules->[$next]->once($event_name => sub { Test::More::ok(1, "$event_name()"); $$pos += 2 });
    $next += 2;
  }

  if ($re eq 'from_server') {
    $response = $class->_server_write_to_connections($server, $response);
    Test::More::ok(1, substr "sent [$$pos] $response", 0, 80);
    $$pos += 2;
    return;
  }

  Test::More::note("irc_server_messages '$incoming' =~ $re ($response)") if 0;
  return unless $incoming =~ $re;

  $response = $class->_server_write_to_connections($server, $response);
  Test::More::like($incoming, $re, substr term_escape("responded [$$pos] $response"), 0, 80);
  $$pos += 2;
}

sub _server_write_to_connections {
  my ($class, $server, $response) = @_;

  if (ref $response eq 'ARRAY') {
    my @from = @$response == 1 ? ($class, @$response) : (@$response);
    $response = data_section @from;
    die "Could not find data section (@from)" unless $response;
  }

  $server->emit(write => $response);
  $response =~ s!\n!\\x0a!g;
  term_escape $response;
}

sub _stream_write {
  my $stream = shift;
  $stream->{to_connection} .= $_[0] if @_;
  $stream->{to_connection} =~ s/[\015\012]+/\015\012/g;
  return $stream->write(substr($stream->{to_connection}, 0, int(10 + rand 20), ''),
    sub { _stream_write(shift) });
}

1;

__DATA__
@@ join-convos.irc
:Superman!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman #convos :some cool topic
:hybrid8.debian.local 333 Superman #convos superman!superman@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman = #convos :Superman @batman
:hybrid8.debian.local 366 Superman #convos :End of /NAMES list.
@@ identify.irc
:NickServ!clark.kent\@i.love.debian.org PRIVMSG #superman :You are now identified for batman
@@ ison.irc
:hybrid8.debian.local 303 test21362 :private_ryan
@@ welcome.irc
:hybrid8.debian.local 001 superman :Welcome to the debian Internet Relay Chat Network superman
@@ start.irc
:hybrid8.local NOTICE AUTH :*** Looking up your hostname...
:hybrid8.local NOTICE AUTH :*** Checking Ident
:hybrid8.local NOTICE AUTH :*** Found your hostname
:hybrid8.local NOTICE AUTH :*** No Ident response
@@ messages.txt
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
