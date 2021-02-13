package Convos::Plugin::Bot;
use Mojo::Base 'Convos::Plugin';

use Convos::Util qw($CHANNEL_RE DEBUG generate_secret pretty_connection_name require_module);
use Mojo::JSON::Pointer;
use Mojo::Util 'camelize';

use constant LOAD_INTERVAL => $ENV{CONVOS_BOT_LOAD_INTERVAL} || 10;

has actions => sub { +{} };
has config  => sub { Mojo::JSON::Pointer->new({}) };
has user    => undef;

has _config_file => undef;

sub action {
  my ($self, $name) = @_;
  my $actions = $self->actions;
  return $actions->{$name} if $actions->{$name};

  $name = camelize $name   if $name =~ m!^[a-z]!;
  return $actions->{$name} if $actions->{$name};

  $name = join '::', 'Convos::Plugin::Bot::Action', $name;
  return $actions->{$name} if $actions->{$name};
}

if (eval 'use YAML::XS 0.67;1') {
  *load_config_file = sub { local $YAML::XS::Boolean = 'JSON::PP'; YAML::XS::LoadFile("$_[1]") };
}
else {
  require YAML::PP;
  my $pp = YAML::PP->new(boolean => 'JSON::PP');
  *load_config_file = sub { $pp->load_file("$_[1]") };
}

sub register {
  my ($self, $app, $config) = @_;
  return unless $config->{email} ||= $ENV{CONVOS_BOT_EMAIL};
  $app->helper(bot => sub {$self});
  $self->_load_config;
  $self->_register_user($app->core, $config);
}

sub _construct_action {
  my ($self, $action_class, $config) = @_;

  require_module $action_class;
  my $home    = $self->user->core->home->child($self->user->email);
  my $enabled = $config->{enabled} // 1;
  my $action  = $action_class->new(config => $self->config, enabled => $enabled, home => $home);
  $action->register($self, $config);
  $self->_log->info(qq($action_class is @{[$action->enabled ? 'enabled' : 'disabled']}.));
  return $action;
}

sub _conversation_join {
  my ($self, $connection, $conversation_config) = @_;
  my $conversation = $connection->conversation({name => $conversation_config->{conversation_id}});

  $conversation->password($conversation_config->{password}) if $conversation_config->{password};
  return $conversation->frozen('Not connected.') unless $connection->state eq 'connected';

  my $command = sprintf '/join %s', $conversation->name;
  $command .= ' ' . $conversation->password if $conversation->password;
  $connection->send_p('', $command)->catch(sub {
    $self->_log->info(sprintf 'Bot send "%s": %s', $command, pop);
  });
}

sub _conversation_part {
  my ($self, $connection, $conversation_config) = @_;
  my $conversation = $connection->conversation_remove(lc $conversation_config->{conversation_id});
  return unless $connection->state eq 'connected';

  my $command = sprintf '/part %s', $conversation->name;
  $connection->send_p('', $command)->catch(sub {
    $self->_log->info(sprintf 'Bot send "%s": %s', $command, pop);
  });
}

sub _ensure_action {
  my ($self, $config) = @_;
  my $action_class = $config->{class} or return;
  my $action;

  eval {
    $action = $self->actions->{$action_class} ||= $self->_construct_action($action_class, $config);
    $self->_log->info(qq($action_class is @{[$config->{enabled} ? 'enabled' : 'disabled']}.))
      if defined $config->{enabled} and $config->{enabled} != $action->enabled;
    $self->config->data->{action}{$action_class} = $config;
    $action->enabled($config->{enabled} // 1);
  } or do {
    delete $self->actions->{$action_class};
    $self->_log->error("Couldn't register bot action $action_class: $@");
  };
}

sub _ensure_connection {
  my ($self, $config) = @_;
  return unless $config->{url};

  my $url           = Mojo::URL->new($config->{url});
  my $user          = $self->user;
  my %attrs         = (name => pretty_connection_name($url), protocol => $url->scheme);
  my $connection_id = join '-', @attrs{qw(protocol name)};
  $self->config->data->{connection}{$connection_id} = $config;

  my $has_connection = $user->get_connection($connection_id) && 1;
  my $connection     = $user->connection(\%attrs);
  $connection->on(state => sub { $self and $self->_on_state(@_) }) unless $has_connection;
  $connection->url($url);
  $connection->wanted_state($config->{wanted_state} || 'connected');

  my $conversations = $config->{conversations} || {};
  for my $conversation_id (keys %$conversations) {
    my $conversation_method
      = ($conversations->{$conversation_id}{state} || '') eq 'part'
      ? '_conversation_part'
      : '_conversation_join';
    local $conversations->{$conversation_id}{conversation_id} = $conversation_id;
    $self->$conversation_method($connection, $conversations->{$conversation_id});
  }

  my $state_method = $connection->wanted_state eq 'connected' ? 'connect_p' : 'disconnect_p';
  $connection->$state_method unless $connection->state eq $connection->wanted_state;
  $self->_log->info(
    "Bot connection @{[$connection->url]} has wanted state @{[$connection->wanted_state]}.");
}

sub _load_config {
  my $self = shift;
  return unless $self->_config_file and -s $self->_config_file;

  my $ts = $self->_config_file->stat->mtime;
  return if $self->config->data->{ts} and $ts == $self->config->data->{ts};

  $self->_log->info("Reloading @{[$self->_config_file]}");
  my $config = $self->load_config_file($self->_config_file);
  @$config{qw(action connection ts)} = ({}, {}, $ts);
  $config->{$_} ||= [] for qw(actions connections);
  my $old_password = $self->config->get('/generic/password') || '';
  $self->config->data($config);

  my $password = $self->config->get('/generic/password');
  $self->user->set_password($password) if $self->user and $password and $old_password ne $password;
  $self->_ensure_action($_)     for @{$self->config->get('/actions')};
  $self->_ensure_connection($_) for @{$self->config->get('/connections')};
}

sub _log {
  shift->user->core->log;
}

sub _on_state {
  my ($self, $connection, $type, $event) = @_;
  $self->_log->info("Bot connection @{[$connection->id]} got state event $type");
  $connection->_write_p("MODE $event->{nick} +B\r\n") if $type eq 'me' and $event->{nick};
}

sub _register_user {
  my ($self, $core, $config) = @_;

  # Prevent bot from becoming the admin user
  return Mojo::IOLoop->timer(1 => sub { $self->_register_user($core, $config) })
    unless $core->n_users or $ENV{CONVOS_BOT_ALLOW_STANDALONE};

  # Bot account exists
  my $user     = $core->get_user($config->{email});
  my $password = $self->config->get('/generic/password');
  $user->set_password($password) if $password;

  return $self->user($user)->_user_is_registered if $user;

  # Register bot account
  $password ||= generate_secret;
  $user = $core->user({email => $config->{email}})->role(give => 'bot')->set_password($password);
  $user->save_p->then(sub {
    $core->log->info(qq(Created bot account $config->{email} with password "$password".))
      unless $self->config->get('/generic/password');
    $self->user($user)->_user_is_registered;
  })->catch(sub {
    my $err = shift;
    $core->log->error(qq(Couln't create bot account $config->{email}: $err));
  });
}

sub _run_actions_with_message {
  my ($self, $event) = @_;
  return unless $event->{conversation_id} and $event->{from};

  my $connection = $self->user->get_connection($event->{connection_id});
  return if lc $event->{from} eq lc $connection->nick;

  local $event->{is_private} = $event->{conversation_id} =~ m!^$CHANNEL_RE! ? 0 : 1;
  local $event->{my_nick}    = $connection->nick;

  my $reply;
  for my $config (@{$self->config->get('/actions')}) {
    my $action = $self->actions->{$config->{class}};
    next unless $action and $action->enabled;
    $action->emit(message => $event);
    $reply = $action->reply($event) unless $reply;
  }

  return unless $reply;
  my $delay = $self->config->get('/generic/reply_delay') || 0.5;
  Scalar::Util::weaken($connection);
  Mojo::IOLoop->timer(
    $delay => sub { $connection and $connection->send_p($event->{conversation_id}, $reply) });
}

sub _user_is_registered {
  my $self = shift;
  my $core = $self->user->core;
  my $uid  = $self->user->id;

  $core->backend->on(
    "user:$uid" => sub {
      my ($backend, $event, $data) = @_;
      my $run_method = sprintf '_run_actions_with_%s', $event;
      $self->$run_method($data) if $self->can($run_method);
    }
  );

  $self->_config_file($core->home->child($self->user->email, 'bot.yaml'));
  Mojo::IOLoop->recurring(LOAD_INTERVAL, sub { $self and $self->_load_config });
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot - A bot system for Convos

=head1 SYNOPSIS

  $ CONVOS_BOT_EMAIL=my_bot@example.com ./script/convos daemon

=head1 DESCRIPTION

L<Convos::Plugin::Bot> is a bot system that integrates tightly with L<Convos>.
This works by registering a user with the email specified by the
C<CONVOS_BOT_EMAIL> environment variable and a random password.

The bot will read C<$CONVOS_HOME/$CONVOS_BOT_EMAIL/bot.yaml> on a regular
interval and act upon the instructions. Some instructions can also be given
using chat commands, if you are a convos admin.

=head2 Example config file

  ---
  generic:
    password: supersecret # Set bot login password
    reply_delay: 1        # Wait one second before posting reply

  # The order of actions is significant, since the first action
  # that generates a reply wins.
  actions:
  - class: Convos::Plugin::Bot::Action::Core
  - class: Convos::Plugin::Bot::Action::Karma
  - class: Convos::Plugin::Bot::Action::Calc

  # Default config parameters can be specified for each action,
  # and overridden per connection or channel
  - class: Convos::Plugin::Bot::Action::Hailo
    free_speak_ratio: 0
    reply_on_highlight: 0

  # Specify which servers to connect to
  connections:
  - url: 'irc://localhost:6667?tls=0'
    wanted_state: connected          # connected (default), disconnected
    actions:
      Convos::Plugin::Bot::Action::Hailo:
        free_speak_ratio: 0.001      # override "free_speak_ratio" for any conversation on freenode
    conversations:
      "#convos":
        password: s3cret             # optional
        state: join                  # join (default), part
        actions:
          Convos::Plugin::Bot::Action::Hailo:
            free_speak_ratio: 0.5    # override "free_speak_ratio" for #convos on freenode

=head2 Actions

"Actions" are modules that provide the bot with functionality. Each action can
react to messages and/or generate replies. Bundled with Convos you have some
core actions, but you can also write your own. The core actions are:

=over 2

=item * L<Convos::Plugin::Bot::Action::Calc>

=item * L<Convos::Plugin::Bot::Action::Core>

=item * L<Convos::Plugin::Bot::Action::Hailo>

=item * L<Convos::Plugin::Bot::Action::Karma>

=back

=head1 HELPERS

=head2 bot

  $bot = $app->bot;
  $bot = $c->bot;

Can be used to access the C<$bot> instance from the C<Convos> web application.

=head1 ATTRIBUTES

=head2 actions

  $hash_ref = $bot->actions;

Holds a key value pair where the keys are C<Convos::Plugin::Bot::> class names
and the value is an instance of that class.

=head2 config

  $pointer = $bot->config;

Holds the global config in a L<Mojo::JSON::Pointer> object.

=head2 user

  $user = $bot->user;

Holds a L<Convos::Core::User> object representing the bot.

=head1 METHODS

=head2 action

  $action = $bot->action($moniker);
  $action = $bot->action($class_name);

Returns an action object by C<$moniker> or C<$class_name>. Example:

  $karma_action = $bot->action("karma");
  $karma_action = $bot->action("Karma");
  $karma_action = $bot->action("Convos::Plugin::Bot::Action::Karma");

=head2 load_config_file

  $hash_ref = $self->load_config_file($path);

Used to load YAML config file and return it as a data structure.

=head2 register

  $bot->register($app, \%config);

Will set up L</user> and start watching L</config> for changes.

=head1 SEE ALSO

L<Convos>, L<Convos::Plugin>.

=cut
