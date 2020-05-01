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
$ENV{MOJO_MODE} ||= 'test';

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
  my $class    = shift;
  my $ts       = shift || time;
  my $interval = shift || 40;

  my @messages = split /\n/, data_section qw(t::Helper messages.txt);
  $ts = $ts =~ /T/ ? Time::Piece->strptime($ts, '%Y-%m-%dT%H:%M:%S') : Time::Piece->gmtime($ts);
  $ts -= $interval * @messages;

  my $i = 0;
  for my $entry (@messages) {
    my ($from, $msg) = split /\s/, $entry, 2;
    my $event = $from =~ s/^-// ? 'notice' : $from =~ s/^\*// ? 'action' : 'private';

    # Test::More::note(sprintf "%s - %s %s\n", $ts->datetime, $from, $msg);
    $entry = {
      from      => $from,
      highlight => $msg =~ /superman/i ? Mojo::JSON->true : Mojo::JSON->false,
      message   => $msg,
      ts        => $ts,
      type      => $event,
    };
    $ts += $interval;
  }

  return @messages;
}

sub t {
  require Test::Mojo;
  return Test::Mojo->new($_[1] || 'Convos');
}

sub t_selenium {
  my ($class, $app) = @_;
  Test::More::plan(skip_all => './script/convos cpanm Test::Mojo::Role::Selenium')
    unless eval 'require Test::Mojo::Role::Selenium;1';

  $ENV{CONVOS_BACKEND}            ||= 'Convos::Core::Backend';
  $ENV{CONVOS_DEFAULT_CONNECTION} ||= 'irc://irc.convos.by/%23convos';
  $ENV{MOJO_SELENIUM_DRIVER}      ||= 'Selenium::Firefox';
  $ENV{MOJO_MODE} = 'development' if $ENV{MOJO_MODE} eq 'test';

  require Test::Mojo;
  my $t = Test::Mojo->with_roles('+Selenium')->new($app || 'Convos')->setup_or_skip_all;
  $t->set_window_size([1024, 768])->navigate_ok('/')->status_is(200);

  return $t;
}

sub t_selenium_register {
  my ($class, $t) = @_;
  $t->wait_for('#signup')->send_keys_ok('#signup [name=email]', 'jhthorsen@cpan.org')
    ->send_keys_ok('#signup [name=password]', 'superduper')->click_ok('#signup .btn.for-save')
    ->wait_for(0.2)->wait_for('.messages-container');
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
river 0 pencil
arm 1 kettle
place 2 story
teaching 3 trade
coil 4 smile
yard 5 power
insect 6 cap
table 7 advice
lamp 8 invention
income 9 frog
caption 10 teeth
machine 11 dog
quarter 12 pets
self 13 top
anger 14 fowl
vacation 15 society
berry 16 playground
shirt 17 low
bag 18 class
trip 19 governor
regret 20 men
industry 21 bed
name 22 sky
*coach 23 kittens
rake 24 wound
copper 25 card
driving 26 picture
guide 27 thing
stage 28 vase
birds 29 art
school 30 vest
wood 31 question
lunch 32 punishment
deer 33 treatment
eyes 34 recess
loaf 35 pot
roll 36 meal
discussion 37 notebook
verse 38 hobbies
account 39 guitar
month 40 pin
degree 41 letters
blade 42 level
field 43 pie
glove 44 control
veil 45 aunt
*doll 46 bee
credit 47 potato
plot 48 acoustics
airport 49 yard
doctor 50 curtain
basketball 51 title
shade 52 secretary
truck 53 loss
-vacation 54 cabbage
-wall 55 superman notification
-stitch 56 baby
-throat 57 bikes
-behavior 58 milk
cow 59 underwear
achiever 60 representative
wound 61 substance
profit 62 toys
shoe 63 argument
destruction 64 appliance
chalk 65 canvas
can 66 stamp
lettuce 67 steam
desk 68 shape
cub 69 pleasure
muscle 70 zinc
cough 71 property
change 72 pear
*boundary 73 boot
company 74 unit
quince 75 bath
wax 76 pest
lip 77 number
flock 78 rings
volleyball 79 guide
toad 80 bead
