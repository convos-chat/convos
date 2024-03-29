package Convos::Plugin::Bot::Action;
use Mojo::Base 'Mojo::EventEmitter';

use Carp qw(confess);
use Mojo::Util qw(decamelize);

has bot         => undef, weak => 1;
has config      => sub { Mojo::JSON::Pointer->new({}) };
has description => 'No description.';
has enabled     => 1;
has home        => undef;

has moniker => sub {
  my $moniker = ref $_[0];
  $moniker =~ s!^Convos::Plugin::Bot::Action::!!;
  decamelize $moniker;
};

has usage => 'Not specified.';

sub event_config {
  my ($self, $event, $key) = @_;
  my $action_class = ref $self;
  my $global       = $self->config->data;

  my $action_config = $global->{action}{$action_class};
  my $conn_config   = $event->{connection_id} && $global->{connection}{$event->{connection_id}};
  my $conversation_config
    = $event->{conversation_id}
    && $conn_config
    && $conn_config->{conversations}{$event->{conversation_id}};

  for my $section ($conn_config, $conversation_config) {
    $section = $section && $section->{actions} && $section->{actions}{$action_class};
  }

  for my $section ($conversation_config, $conn_config, $action_config) {
    return $section->{$key} if defined $section->{$key};
  }

  return undef;
}

sub query_db {
  my ($self, $query) = (shift, shift);
  my $sth = $self->_dbh->prepare($query);
  $sth->execute(@_);
  return $sth;
}

sub register { }
sub reply    {undef}

sub _dbh {
  my $self = shift;
  return $self->{dbh} if $self->{dbh} and $self->{dbh}->ping;

  use Convos::Util 'require_module';
  require_module 'DBD::SQLite';

  # back compat
  my $home = $self->home;
  $home->child('karma.sqlite')->move_to('bot_actions.sqlite') if -e $home->child('karma.sqlite');

  return $self->{dbh} = DBI->connect(
    sprintf('dbi:SQLite:dbname=%s', $home->child('bot_actions.sqlite')->to_string),
    '', '',
    {
      AutoCommit          => 1,
      AutoInactiveDestroy => 1,
      PrintError          => 0,
      RaiseError          => 1,
      sqlite_unicode      => 1,
    }
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action - Base class for bot actions

=head1 SYNOPSIS

  package Convos::Plugin::Bot::Action::Beans;
  use Mojo::Base "Convos::Plugin::Bot::Action";

  sub reply {
    my ($self, $event) = @_;
    return "Cool beans!" if $event->{mesages} =~ m/^beans/;
  }

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action> must be used as base class for
L<Convos::Plugin::Bot> actions.

=head1 EVENTS

=head2 message

  $action->on(message => sub { my ($action, $event) = @_ });

This event is emitted from L<Convos::Plugin::Bot>, when the bot sees/receives a
new message. The C<$event> has this structure:

  {
    connection_id   => "irc-something",
    conversation_id => "nick_or_#room_lowercase",
    from            => $nick,
    is_private      => $bool, # true if sent in a private chat
  }

=head1 ATTRIBUTES

=head2 bot

  $bot = $action->bot;

Access the parent L<Convos::Plugin::Bot> object.

=head2 config

  $pointer = $action->config;

Shared config parameters with L<Convos::Plugin::Bot/config>.

=head2 description

  $str = $action->description;

Holds a description of the action, which can be displayed as aid in a
conversation with the bot.

=head2 enabled

  $bool = $action->enabled;
  $action = $action->enabled(0);

Can be set to a boolean value in the config file to enable/disable a given
action.

=head2 home

  $path = $action->home;

Path to where the bot/action can store files.

=head2 moniker

  $str = $action->moniker;

A short nick name for the action class name.

=head2 usage

  $str = $action->usage;

Holds information about the action, which can be displayed as aid in a
conversation with the bot.

=head1 METHODS

=head2 event_config

  $any = $action->event_config(\%event, $config_key);

Used to get a L</config> parameter for the current C<$action> and an event with
C<connection_id> and C<conversation_id>.

C<$event> should have the same structure as the L</message> event.

=head2 query_db

  $sth = $action->query_db($sql, @bind);

Used to run SQL in SQLite database. Example:

  my $sth = $action->query_db('select name from users where id = ?', 42);
  my $user = $sth->fetchrow_hashref;
  warn $user ? $user->{name} : 'not found';

=head2 register

  $action->register($bot, \%config);

Called the first time the C<$action> is loaded by L<Convos::Plugin::Bot>.

=head2 reply

  $str = $action->reply(\%event);

Can be used to generate a reply to a C<%event>. The first
L<Convos::Plugin::Bot::Action> object that returns a C<$str> will be used to
generate a response. This is to prevent the bot from making multiple responses
to the same message.

Return C<undef> to allow the next action to reply.

C<$event> has the same structure as the L</message> event.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
