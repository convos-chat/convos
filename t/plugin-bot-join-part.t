#!perl
BEGIN { $ENV{CONVOS_BOT_LOAD_INTERVAL} = 0.05 }

use lib qw(.);
use t::Helper;
use t::Server::Irc;
use Convos::Util qw(pretty_connection_name);
use Mojo::Loader qw(data_section);

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT} or $ENV{TEST_ALL};

$ENV{CONVOS_BOT_EMAIL} ||= 'botman@convos.chat';
my $server = t::Server::Irc->new(auto_connect => 0)->start;
my $t      = t::Helper->t;
my $core   = $t->app->core;
my $bot    = $t->app->bot;
my $connection;

$server->subtest(
  setup => sub {
    $core->settings->default_connection($server->url);
    $core->settings->open_to_public(true);
    $t->post_ok('/api/user/register',
      json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);

    # wait for the bot to register
    Mojo::IOLoop->one_tick until $bot->user;
  }
);

$server->subtest(
  connect => sub {
    write_config('connect.yaml');

    my $connection_id = join '-', $server->url->scheme, pretty_connection_name($server->url);
    Mojo::IOLoop->one_tick until $connection = $bot->user->get_connection($connection_id);

    $server->client($connection)->server_event_ok('_irc_event_nick')
      ->server_write_ok(['welcome-botman.irc'])->server_event_ok('_irc_event_mode')
      ->process_ok('connected');
  }
);

$server->subtest(
  'join' => sub {
    $server->client($connection)->server_event_ok('_irc_event_join')
      ->server_write_ok(['join-convos.irc'])->client_event_ok('_irc_event_join');
    write_config('join.yaml');
    $server->process_ok('joined');
  }
);

$server->subtest(
  'part' => sub {
    $server->client($connection)->server_event_ok('_irc_event_part')
      ->server_write_ok(":localhost PART #convos\r\n")->client_event_ok('_irc_event_part');
    write_config('part.yaml');
    $server->process_ok('parted');
  }
);

done_testing;

sub write_config {
  my $config = data_section('main', shift);
  $config =~ s!\bCONVOS_DEFAULT_CONNECTION\b!{$server->url->to_string}!ge;
  $core->home->child($ENV{CONVOS_BOT_EMAIL}, 'bot.yaml')->spurt($config);
}

__DATA__
@@ connect.yaml
connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: connected

@@ join.yaml
connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: connected
  conversations:
    '#convos': ~

@@ part.yaml
connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: connected
  conversations:
    '#Convos':
      state: part

@@ join-convos.irc
:Superman!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman #convos :some cool topic
:hybrid8.debian.local 333 Superman #convos superman!superman@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman = #convos :Superman @batman
:hybrid8.debian.local 366 Superman #convos :End of /NAMES list.
@@ welcome-botman.irc
:hybrid8.debian.local 001 botman :Welcome to the debian Internet Relay Chat Network botman
