use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Plugin::Bot::Action::Spool;

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_ALLOW_STANDALONE} = 1;
$ENV{CONVOS_BOT_SPOOL_INTERVAL}   = 0.01;
$ENV{CONVOS_BOT_EMAIL} ||= 'bot@convos.chat';

my $t      = t::Helper->t;
my $server = t::Server::Irc->new->start;

my $bot   = $t->app->bot;
my $spool = Convos::Plugin::Bot::Action::Spool->new;
$spool->register($bot, {});
$spool->_dir->child('whatever.yml')->spurt(test_file());

my $connection = $bot->user->connection({protocol => 'irc', name => 'localhost'});
my $event;
$server->client($connection)->server_event_ok('_irc_event_privmsg', sub { $event = pop })
  ->process_ok;
is $event->{raw_line}, ':bot PRIVMSG #convos :too cool!', 'sent message';

done_testing;

sub test_file {
  return <<'HERE';
connection_id: irc-localhost
conversation_id: "#convos"
message: too cool!
HERE
}
