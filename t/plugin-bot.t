#!perl
BEGIN { $ENV{CONVOS_BOT_LOAD_INTERVAL} = 0.05 }

use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Util 'pretty_connection_name';
use Mojo::Loader 'data_section';

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_EMAIL} ||= 'botman@convos.chat';
my $server = t::Server::Irc->new(auto_connect => 0)->start;
my $t      = t::Helper->t;
my $core   = $t->app->core;

my $bot = $t->app->bot;
ok $bot->isa('Convos::Plugin::Bot'), 'bot helper';

is $core->n_users, 0, 'bot will not register before the first user';

$core->settings->default_connection($server->url);
$core->settings->open_to_public(true);
$t->post_ok('/api/user/register',
  json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);
is $core->n_users, 1, 'superman registered';

Mojo::Promise->timer(1)->wait;
is $core->n_users, 2, 'bot is registered as well';

note 'load two_actions.yaml';
my $config_file = $core->home->child($ENV{CONVOS_BOT_EMAIL}, 'bot.yaml');
note $config_file;
$config_file->spurt(config('two_actions.yaml'));
Mojo::Promise->timer(0.05)->wait;
ok $bot->action($_), "$_ present" for qw(core karma);
ok !$bot->action('hailo'), "Convos::Plugin::Bot::Action::Hailo not present";
ok !$bot->user->validate_password('supersecret'), 'generated password';

my $connection_id = join '-', $server->url->scheme, pretty_connection_name($server->url);
my $connection    = $bot->user->get_connection($connection_id);
ok $connection, 'bot connection';

note 'load all_actions.yaml';
delete $bot->config->data->{ts};
my $msg;
$server->client($connection)->server_event_ok('_irc_event_nick')
  ->server_write_ok(['welcome-botman.irc'])->server_event_ok('_irc_event_mode', sub { $msg = pop })
  ->server_event_ok('_irc_event_join');
$config_file->spurt(config('all_actions.yaml'));
$server->process_ok('mode +B');
ok $bot->action('hailo'),                              'action by a-z';
ok $bot->action('Hailo'),                              'action by A-Z';
ok $bot->action('Convos::Plugin::Bot::Action::Hailo'), 'action by fqn';
is $bot->action('hailo')->config, $bot->config, 'config is shared';
like $msg->{raw_line}, qr{MODE botman \+B}, 'mode +B';

my $hailo = $bot->action('hailo');
my $event = {};
is $hailo->event_config($event, 'superduper'), undef, 'default superduper';
$event->{connection_id}   = $connection_id;
$event->{conversation_id} = '#superduper';
is $hailo->event_config($event, 'free_speak_ratio'), 0.001, 'connection free_speak_ratio';
$event->{conversation_id} = '#convos';
is $hailo->event_config($event, 'free_speak_ratio'), 0.5, 'conversation free_speak_ratio';

note 'make sure we do not reply multiple times when reloading config';
for my $name (qw(two_actions.yaml all_actions.yaml all_actions.yaml)) {
  delete $bot->config->data->{ts};
  $config_file->spurt(config($name));
  Mojo::Promise->timer(0.1)->wait;
}

note 'custom password';
ok $bot->user->validate_password('supersecret'), 'password from config file';

my $replied = 0;
Mojo::Util::monkey_patch('Convos::Plugin::Bot::Action::Core',
  reply => sub { $replied++; 'Some help' });
$server->client($connection)->server_write_ok(":superman!sg\@example.com PRIVMSG botman :Help\r\n")
  ->server_event_ok('_irc_event_privmsg', sub { $event = pop })
  ->process_ok('superman writes botman');
$server->client($core->get_user('superman@example.com')->connections->[0])
  ->server_write_ok("$event->{raw_line}\r\n")
  ->client_event_ok('_irc_event_privmsg', sub { $event = pop })
  ->process_ok('botman replies to superman');
is $event->{params}[1], 'Some help', 'got reply to help';
is $replied, 1, 'does not reply to own messages';

done_testing;

sub config {
  my $config = data_section('main', shift);
  $config =~ s!\bCONVOS_DEFAULT_CONNECTION\b!{$server->url->to_string}!ge;
  return $config;
}

__DATA__
@@ two_actions.yaml
actions:
- class: Convos::Plugin::Bot::Action::Core
- class: Convos::Plugin::Bot::Action::Karma

connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: disconnected

@@ all_actions.yaml
generic:
  password: supersecret
  reply_delay: 0.1
actions:
- class: Convos::Plugin::Bot::Action::Core
- class: Convos::Plugin::Bot::Action::Karma
  enabled: false
- class: Convos::Plugin::Bot::Action::Calc
  enabled: false
- class: Convos::Plugin::Bot::Action::Hailo
  enabled: false
  free_speak_ratio: 0
  reply_on_highlight: 0

# Specify which servers to connect to
connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: connected
  actions:
    Convos::Plugin::Bot::Action::Hailo:
      free_speak_ratio: 0.001
  conversations:
    "#convos":
      actions:
        Convos::Plugin::Bot::Action::Hailo:
          free_speak_ratio: 0.5

@@ welcome-botman.irc
:hybrid8.debian.local 001 botman :Welcome to the debian Internet Relay Chat Network botman
