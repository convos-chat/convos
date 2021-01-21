use lib '.';
use t::Helper;
use Convos::Plugin::Bot::Action::Core;

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_ALLOW_STANDALONE} = 1;
$ENV{CONVOS_BOT_EMAIL} ||= 'bot@convos.chat';

my $t    = t::Helper->t;
my $core = Convos::Plugin::Bot::Action::Core->new;

$t->app->bot->actions->{'Convos::Plugin::Bot::Action::Core'} = $core;
$core->register($t->app->bot, {});

is $core->reply({message => 'help'}), undef, 'is_private';

is $core->reply({is_private => 1, message => 'actions'}), 'Only core action enabled.', 'actions';

is $core->reply({is_private => 1, message => 'about'}), 'Core bot functionality.', 'about';
is $core->reply({is_private => 1, message => 'about foo'}), qq(Couldn't find action "foo".),
  'about foo';

is $core->reply({is_private => 1, message => 'help'}),
  'Commands: actions, about <action>, help <action>.', 'help';
is $core->reply({is_private => 1, message => 'help core'}),
  'Commands: actions, about <action>, help <action>.', 'help core';
is $core->reply({is_private => 1, message => 'help calc'}), qq(Couldn't find action "calc".),
  'help calc';

$t->app->bot->actions->{'Convos::Plugin::Bot::Action::Foo'} = Convos::Plugin::Bot::Action->new(
  description => 'Foo bar baz.',
  usage       => 'foo before bar and maybe baz.',
);
is $core->reply({is_private => 1, message => 'about foo'}), qq(Foo bar baz.), 'about foo';
is $core->reply({is_private => 1, message => 'help foo'}), qq(foo before bar and maybe baz.),
  'help foo';

done_testing;

