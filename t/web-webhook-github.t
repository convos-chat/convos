#!perl
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

subtest 'setup' => sub {
  $core->home->child($ENV{CONVOS_BOT_EMAIL})->make_path;
  write_config('github.yaml');
  $core->settings->default_connection($server->url);
  $core->settings->open_to_public(true);
  $t->post_ok('/api/user/register',
    json => {email => 'superman@example.com', password => 'longenough'})->status_is(200);
  Mojo::Promise->timer(2)->wait;
};

subtest 'input validation' => sub {
  $t->post_ok('/api/webhook/github', json => {action => 'closed'})->status_is(400)
    ->json_is('/errors/0/path', '/X-GitHub-Event');
  $t->post_ok('/api/webhook/github', {'X-GitHub-Event' => 'issues'}, json => {action => 'closed'})
    ->status_is(403)->json_like('/errors/0/message', qr{Invalid source IP});
};

subtest 'delivered' => sub {
  @Convos::Controller::Webhook::GITHUB_WEBHOOK_NETWORKS = qw(127.0.0.0/24);
  my $json = {
    action     => 'opened',
    issue      => {html_url  => 'https://x.y.z', number => 42, title => 'Cool beans'},
    repository => {full_name => 'convos-chat/convos', name => 'convos'},
    sender     => {login     => 'jhthorsen'},
  };
  $t->post_ok('/api/webhook/github', {'X-GitHub-Event' => 'issues'}, json => $json)->status_is(200)
    ->json_is('/delivered', true);
};

done_testing;

sub write_config {
  my $config = data_section('main', shift);
  $config =~ s!\bCONVOS_DEFAULT_CONNECTION\b!{$server->url->to_string}!ge;
  $core->home->child($ENV{CONVOS_BOT_EMAIL}, 'bot.yaml')->spurt($config);
}

__DATA__
@@ github.yaml
actions:
- class: Convos::Plugin::Bot::Action::Github
  repositories:
    'convos-chat/convos':
    - events: [ fork, issues, milestone, pull_request, star ]
      to: [ 'irc-localhost', '#convos' ]

connections:
- url: CONVOS_DEFAULT_CONNECTION
  wanted_state: connected
  conversations:
    '#convos': ~

@@ join-convos.irc
:Superman!superman@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 Superman #convos :some cool topic
:hybrid8.debian.local 333 Superman #convos superman!superman@i.love.debian.org 1432932059
:hybrid8.debian.local 353 Superman = #convos :Superman @batman
:hybrid8.debian.local 366 Superman #convos :End of /NAMES list.
@@ welcome-botman.irc
:hybrid8.debian.local 001 botman :Welcome to the debian Internet Relay Chat Network botman
