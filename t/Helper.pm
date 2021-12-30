package t::Helper;
use Mojo::Base -strict;

use Convos;
use Convos::Date 'dt';
use File::Basename 'basename';
use File::Path ();
use FindBin;
use Mojo::IOLoop;
use Mojo::Loader 'data_section';
use Mojo::URL;
use Mojo::Util 'term_escape';

our $CONVOS_HOME;

$ENV{CONVOS_I18N_CAPTURE_LEXICONS} ||= 1;
$ENV{CONVOS_GENERATE_CERT} //= 0;
$ENV{CONVOS_SECRETS} = 'not-very-secret';
$ENV{OPENSSL_BITS} ||= 1024;

sub subprocess_in_main_process {
  require Mojo::IOLoop::Subprocess;
  Mojo::Util::monkey_patch(
    'Mojo::IOLoop::Subprocess' => run_p => sub {
      my ($subprocess, $child, $parent) = @_;
      my @res = eval { $subprocess->$child };
      return $@ ? Mojo::Promise->reject($@) : Mojo::Promise->resolve(@res);
    }
  );
}

sub with_csrf {
  my ($t, $path) = @_;
  my $token = $t->get_ok('/chat')->tx->res->dom->at('meta[name=csrf]')->{content} // 'undef';
  return $t->get_ok("$path?csrf=$token");
}

sub messages {
  my $class    = shift;
  my $ts       = shift || time;
  my $interval = shift || 40;

  my @messages = split /\n/, data_section qw(t::Helper messages.txt);
  $ts -= $interval * @messages - $interval;
  $ts = dt $ts;

  Test::More::note("Adding messages ts=$ts, interval=$interval\n");
  my $i = 0;
  for my $entry (@messages) {
    my ($from, $msg) = split /\s/, $entry, 2;
    my $event = $from =~ s/^-// ? 'notice' : $from =~ s/^\*// ? 'action' : 'private';

    # Test::More::note(sprintf "%s - %s %s\n", $ts->datetime, $from, $msg);
    $entry = {
      from      => $from,
      highlight => $msg =~ /superman/i ? Mojo::JSON->true : Mojo::JSON->false,
      message   => $msg,
      ts        => "$ts",
      type      => $event,
    };

    $ts += $interval;
  }

  return @messages;
}

sub t {
  require Test::Mojo;
  my $t = Test::Mojo->new($_[1] || 'Convos');
  Mojo::IOLoop->one_tick until $t->app->core->ready;
  return $t;
}

sub t_selenium {
  my ($class, $app) = @_;
  Test::More::plan(skip_all => './script/convos cpanm Test::Mojo::Role::Selenium')
    unless eval 'require Test::Mojo::Role::Selenium;1';

  $ENV{CONVOS_BACKEND}            ||= 'Convos::Core::Backend';
  $ENV{CONVOS_DEFAULT_CONNECTION} ||= 'irc://irc.convos.chat/%23convos';
  $ENV{MOJO_SELENIUM_DRIVER}      ||= 'Selenium::Firefox';

  require Test::Mojo;
  my $t = Test::Mojo->with_roles('+Selenium')->new($app || 'Convos')->setup_or_skip_all;
  $t->set_window_size([1024, 768])->navigate_ok('/login')->status_is(200);

  return $t;
}

sub t_selenium_register {
  my ($class, $t) = @_;
  $t->wait_for('#signup')->send_keys_ok('#signup [name=email]', 'jhthorsen@cpan.org')
    ->send_keys_ok('#signup [name=password]', 'superduper')->click_ok('#signup .btn.for-save')
    ->wait_for(0.2)->wait_for('.main.is-above-chat-input');
}

sub wait_reject {
  my ($p, $err, $desc) = (shift, shift, @_ % 2 ? pop : '');
  my $got;
  $p->then(sub { }, sub { $got = shift // ''; })->wait;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  $desc ||= !ref $err && $err ? $err : 'promise rejected';
  Test::More::is($got, $err, $desc);
  return $p;
}

sub wait_success {
  my ($p,   $desc) = (shift, @_ % 2 ? pop : 'promise resolved');
  my ($err, @res)  = (undef);
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
  if ($CONVOS_HOME and -d $CONVOS_HOME) {
    Test::More::note("remove_tree $CONVOS_HOME");
    File::Path::remove_tree($CONVOS_HOME);
  }
}

1;

__DATA__
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
shoe 22 sky
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
profit 65 canvas
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
