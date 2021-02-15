use lib '.';
use t::Helper;
use Mojo::File qw(tempdir);
use Convos::Plugin::Bot::Action::Facts;

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_ALLOW_STANDALONE} = 1;
$ENV{CONVOS_BOT_EMAIL} ||= 'superbot@convos.chat';

my $t     = t::Helper->t;
my $facts = Convos::Plugin::Bot::Action::Facts->new(home => tempdir);

$facts->register($t->app->bot, {});

$facts->emit(message => {my_nick => 'superbot', message => 'what is convos ?  ...'});
is $facts->query_db('select count(*) from facts')->fetchrow_arrayref->[0], 0,
  'did not learn a question';

$facts->emit(message =>
    {my_nick => 'superbot', message => 'some super duper long topic thing is too long to learn'});
is $facts->query_db('select count(*) from facts')->fetchrow_arrayref->[0], 0,
  'did not learn long topic';

$facts->emit(message => {my_nick => 'superbot', message => 'foo bar baz'});
$facts->emit(message => {my_nick => 'superbot', message => 'Convos is an app'});
is $facts->query_db('select count(*) from facts')->fetchrow_arrayref->[0], 1, 'got one fact';

is $facts->reply({my_nick => 'superbot', message => ''}), undef, 'missing message';
is $facts->reply({my_nick => 'superbot', message => 'what is convos?'}), 'Convos is an app',
  'what is convos?';
is $facts->reply({my_nick => 'superbot', message => 'CONVOS?'}), 'Convos is an app', 'CONVOS?';

$facts->emit(message => {my_nick => 'superbot', message => ' superbot:   convos is a web app!'});
is $facts->reply({my_nick => 'superbot', message => 'whatever'}),
  'I learned something new about convos.', 'reply when learning';

$facts->emit(message => {my_nick => 'superbot', message => 'convos is a too cool for school'});
is $facts->reply({my_nick => 'superbot', message => 'what are convos?'}), 'convos is a web app!',
  'what are convos?';

$facts->emit(message => {my_nick => 'superbot', message => 'The bird says cool stuff'});
is $facts->reply({my_nick => 'superbot', message => q(what isn't the bird?)}),
  'The bird says cool stuff', 'the bird';

$facts->emit(message => {my_nick => 'superbot', message => 'The bird is high up'});
is $facts->reply({my_nick => 'superbot', message => q(what is the bird?)}), 'The bird is high up',
  'the bird is...';
is $facts->reply({my_nick => 'superbot', message => q(what says the bird?)}),
  'The bird says cool stuff', 'the bird is...';

is $facts->query_db('select count(*) from facts')->fetchrow_arrayref->[0], 3, 'more facts';

is $facts->reply({my_nick => 'superbot', message => 'superbot: foobar?'}),
  q(Sorry, I don't know anything about "foobar".), 'unknown fact';

done_testing;
