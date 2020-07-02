#!perl
BEGIN { $ENV{CONVOS_BOT_LOAD_INTERVAL} = 0.05 }

use lib '.';
use t::Helper;
use Convos::Util 'pretty_connection_name';
use Mojo::Loader 'data_section';

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT};

t::Helper->make_default_server;

$ENV{CONVOS_BOT_EMAIL} ||= 'bot@convos.chat';
my $t    = t::Helper->t;
my $core = $t->app->core;

my $bot = $t->app->bot;
ok $bot->isa('Convos::Plugin::Bot'), 'bot helper';

is $core->n_users, 0, 'bot will not register before the first user';

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

my $connection_url = Mojo::URL->new($ENV{CONVOS_DEFAULT_CONNECTION});
my $connection_id  = join '-', $connection_url->scheme,
  pretty_connection_name($connection_url->host);
ok $bot->user->get_connection($connection_id), 'bot connection';

note 'load all_actions.yaml';
delete $bot->config->data->{ts};
$config_file->spurt(config('all_actions.yaml'));
Mojo::Promise->timer(0.1)->wait;
ok $bot->action('hailo'),                              'action by a-z';
ok $bot->action('Hailo'),                              'action by A-Z';
ok $bot->action('Convos::Plugin::Bot::Action::Hailo'), 'action by fqn';
is $bot->action('hailo')->config, $bot->config, 'config is shared';

my $hailo = $bot->action('hailo');
my $event = {};
is $hailo->event_config($event, 'superduper'), undef, 'default superduper';
$event->{connection_id} = $connection_id;
$event->{dialog_id}     = '#superduper';
is $hailo->event_config($event, 'free_speak_ratio'), 0.001, 'connection free_speak_ratio';
$event->{dialog_id} = '#convos';
is $hailo->event_config($event, 'free_speak_ratio'), 0.5, 'dialog free_speak_ratio';

my $user_event_name = sprintf 'user:%s', $bot->user->id;
$core->backend->emit(
  $user_event_name => message => {
    connection_id => $connection_id,
    dialog_id     => 'superwoman',
    from          => 'superwoman',
    highlight     => false,
    message       => 'Help!',
    ts            => time,
    type          => 'private',
  }
);

done_testing;

sub config {
  my $config = data_section('main', shift);
  $config =~ s!\bCONVOS_DEFAULT_CONNECTION\b!$ENV{CONVOS_DEFAULT_CONNECTION}!g;
  return $config;
}

__DATA__
@@ two_actions.yaml
actions:
- class: Convos::Plugin::Bot::Action::Core
- class: Convos::Plugin::Bot::Action::Karma

connections:
- url: CONVOS_DEFAULT_CONNECTION

@@ all_actions.yaml
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
  actions:
    Convos::Plugin::Bot::Action::Hailo:
      free_speak_ratio: 0.001
  dialogs:
    "#convos":
      actions:
        Convos::Plugin::Bot::Action::Hailo:
          free_speak_ratio: 0.5
