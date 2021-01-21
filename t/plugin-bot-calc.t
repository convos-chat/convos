use lib '.';
use t::Helper;
use Convos::Plugin::Bot::Action::Calc;

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_ALLOW_STANDALONE} = 1;
$ENV{CONVOS_BOT_EMAIL} ||= 'bot@convos.chat';

my $t    = t::Helper->t;
my $calc = Convos::Plugin::Bot::Action::Calc->new;

$calc->register($t->app->bot, {});

is $calc->reply({message => 'calc 2 + 2'}),              '2 + 2 = 4',                 'calc 2 + 2';
is $calc->reply({message => 'calc rm -rf .'}),           'Invalid function "rm"',     'rm';
is $calc->reply({message => 'calc system("rm -rf .")'}), 'Invalid function "system"', 'system rm';
is $calc->reply({message => 'calc 10 / 0'}), 'Error in function "/": Illegal division by zero',
  'calc 10 / 2';
is $calc->reply({message => 'calc: sqrt(4)'}), 'sqrt(4) = 2', 'calc sqrt(4)';

done_testing;
