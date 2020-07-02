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

  $name = camelize $name if $name =~ m!^[a-z]!;
  return $actions->{$name} if $actions->{$name};

  $name = join '::', 'Convos::Plugin::Bot::Action', $name;
  return $actions->{$name} if $actions->{$name};
}

sub register {
  my ($self, $app, $config) = @_;
  return unless $config->{email} ||= $ENV{CONVOS_BOT_EMAIL};
  require_module 'YAML::XS';
  $app->helper(bot => sub {$self});
  $self->_register_user($app->core, $config);
}

sub _construct_action {
  my ($self, $action_class, $config) = @_;

  require_module $action_class;
  my $action = $action_class->new(config => $self->config, enabled => $config->{enabled} // 1);
  $action->register($self, $config);
  $self->_log->info(qq($action_class is @{[$action->enabled ? 'enabled' : 'disabled']}.));
  return $action;
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
    $self->_log->error("Couldn't register bot action $action_class: $@");
  };
}

sub _ensure_connection {
  my ($self, $config) = @_;
  return unless $config->{url};

  my $url  = Mojo::URL->new($config->{url});
  my $user = $self->user;
  $config->{name}     = pretty_connection_name($url->host);
  $config->{protocol} = $url->scheme;

  my $connection_id = join '-', @$config{qw(protocol name)};
  my $connection    = $user->get_connection($connection_id);
  $self->config->data->{connection}{$connection_id} = $config;
  return $self->_ensure_dialogs($connection, $config) if $connection;

  $connection = $user->connection($config);
  my $state_method
    = ($config->{state} // 'connected') eq 'disconnected' ? 'disconnect_p' : 'connect';
  $connection->$state_method;
  $self->_ensure_dialogs($connection, $config);
}

sub _ensure_dialogs {
  my ($self, $connection, $config) = @_;

  my $dialogs = $config->{dialogs} || {};
  for my $dialog_id (keys %$dialogs) {
    my $state   = ($dialogs->{$dialog_id}{state} // 'join') eq 'part' ? 'part' : 'join';
    my $command = sprintf '/%s %s', $state, $dialog_id;
    $command .= " $dialogs->{$dialog_id}{password}" if $dialogs->{$dialog_id}{password};
    $connection->send_p('', $command);
  }
}

sub _load_config {
  my $self = shift;
  return unless -s $self->_config_file;

  my $ts = $self->_config_file->stat->mtime;
  return if $self->config->data->{ts} and $ts == $self->config->data->{ts};

  $self->_log->debug("Reloading @{[$self->_config_file]}");
  my $config = YAML::XS::Load($self->_config_file->slurp);
  @$config{qw(action connection ts)} = ({}, {}, $ts);
  $config->{$_} ||= [] for qw(actions connections);
  $self->config->data($config);

  $self->_ensure_action($_)     for @{$self->config->get('/actions')};
  $self->_ensure_connection($_) for @{$self->config->get('/connections')};
}

sub _log {
  shift->user->core->log;
}

sub _register_user {
  my ($self, $core, $config) = @_;

  # Prevent bot from becoming the admin user
  return Mojo::IOLoop->timer(1 => sub { $self->_register_user($core, $config) })
    unless $core->n_users or $ENV{CONVOS_BOT_ALLOW_STANDALONE};

  # Bot account exists
  my $user = $core->get_user($config->{email});
  return $self->user($user)->_user_is_registered if $user;

  # Register bot account
  my $password = generate_secret;
  $user = $core->user({email => $config->{email}})->role(give => 'bot')->set_password($password);
  $user->save_p->then(sub {
    $core->log->info(qq(Created bot account $config->{email} with password "$password".));
    $self->user($user)->_user_is_registered;
  })->catch(sub {
    my $err = shift;
    $core->log->error(qq(Couln't create bot account $config->{email}: $err));
  });
}

sub _run_actions_with_message {
  my ($self, $event) = @_;
  return unless $event->{dialog_id};

  my $command = $event->{message};
  local $event->{is_private} = $event->{dialog_id} =~ m!^$CHANNEL_RE! ? 0 : 1;
  local $event->{command} = $command =~ s/^\!// ? $command : $event->{is_private} ? $command : '';

  my $reply;
  for my $config (@{$self->config->get('/actions')}) {
    my $action = $self->actions->{$config->{class}};
    next unless $action and $action->enabled;
    $action->emit(message => $event);
    next if $reply or !defined($reply = $action->reply($event));
  }

  $self->user->get_connection($event->{connection_id})->send_p($event->{dialog_id}, $reply)
    if $reply;
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
  $self->_load_config;
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
  - url: irc://chat.freenode.net:6697
    state: connected                 # connected (default), disconnected
    actions:
      Convos::Plugin::Bot::Action::Hailo:
        free_speak_ratio: 0.001      # override "free_speak_ratio" for any conversation on freenode
    dialogs:
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

=head2 register

  $bot->register($app, \%config);

Will set up L</user> and start watching L</config> for changes.

=head1 SEE ALSO

L<Convos>, L<Convos::Plugin>.

=cut
