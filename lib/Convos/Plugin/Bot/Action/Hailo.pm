package Convos::Plugin::Bot::Action::Hailo;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use Convos::Util 'require_module';

has description => 'Natural language conversation simulator.';
has hailo       => undef;
has usage       => 'The bot might respond.';

sub register {
  my ($self, $bot, $config) = @_;
  my $user = $bot->user;

  require_module 'DBD::SQLite';
  require_module 'Hailo';
  my %hailo;
  $hailo{brain}
    = $config->{brain} || $user->core->home->child($user->email, 'hailo.sqlite')->to_string;
  $hailo{engine_class} = $config->{engine_class} || 'Scored';
  $hailo{engine_args}  = $config->{engine_args}  || {};
  $self->hailo(Hailo->new(%hailo));
  $self->on(message => sub { shift->_learn(@_) });
}

sub reply {
  my ($self, $event) = @_;

  my $reply_on_highlight = $self->event_config($event, 'reply_on_highlight');
  return $self->hailo->reply($event->{message}) if $event->{highlight} and $reply_on_highlight;

  my $free_speak_ratio = $self->event_config($event, 'free_speak_ratio');
  return $self->hailo->reply($event->{message}) if $free_speak_ratio and $free_speak_ratio > rand;

  return undef;
}

sub _learn {
  my ($self, $event) = @_;
  return unless $event->{message} =~ m!\S!;

  my $hailo = $self->hailo;
  $hailo->learn($event->{message});
  $hailo->save;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Hailo - Markov bot engine analogous to MegaHAL

=head1 SYNOPSIS

=head2 Prerequisites

You need to install L<DBD::SQLite> and L<Hailo> to use this action:

  ./script/convos cpanm -n DBD::SQLite
  ./script/convos cpanm -n Hailo

=head2 Commands

Hailo does not have any specific commands, but will rather try to participate
in a conversation.

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Hailo
    engine_class: Scored
    engine_args:
      interval: 0.5

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Hailo> adds a natural language conversation
simulator to L<Convos::Plugin::Bot>.

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head2 usage

See L<Convos::Plugin::Bot::Action/usage>.

=head1 METHODS

=head2 register

Loads and configures L<Hailo> to use the C<hailo.sqlite> database.

=head2 reply

Will reply when spoken to or ranomly if configued to.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
