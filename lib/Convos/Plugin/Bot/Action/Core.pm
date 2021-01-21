package Convos::Plugin::Bot::Action::Core;
use Mojo::Base 'Convos::Plugin::Bot::Action';

has bot         => undef;
has description => 'Core bot functionality.';
has usage       => 'Commands: actions, about <action>, help <action>.';

sub register {
  my ($self, $bot, $config) = @_;
  $self->bot($bot);
  Scalar::Util::weaken($self->{bot});
}

sub reply {
  my ($self, $event) = @_;
  return undef unless $event->{is_private};
  return $self->usage            if $event->{message} =~ m/^\s*help\W*$/i;
  return $self->description      if $event->{message} =~ m/^\s*about\s*$/i;
  return $self->_reply_about($1) if $event->{message} =~ m/^\s*about\s+(\S+)\W*$/i;
  return $self->_reply_actions   if $event->{message} =~ m/^\s*actions\W*$/i;
  return $self->_reply_help($1)  if $event->{message} =~ m/^\s*help\s+(\S+)\W*$/i;
  return undef;
}

sub _reply_about {
  my ($self, $name) = @_;
  my $action = $self->bot->action($name);
  return $action ? $action->description : qq(Couldn't find action "$name".);
}

sub _reply_actions {
  my $self    = shift;
  my @actions = grep { $_->enabled && ref($_) ne __PACKAGE__ } values %{$self->bot->actions};
  return sprintf 'Available actions: %s.', join ', ', map { $_->moniker } @actions if @actions;
  return 'Only core action enabled.';
}

sub _reply_help {
  my ($self, $name) = @_;
  my $action = $self->bot->action($name);
  return $action ? $action->usage : qq(Couldn't find action "$name".);
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Core - Core functionality for Convos bot

=head1 SYNOPSIS

=head2 Commands

=over 2

=item * actions

List all actions available.

=item * about <action>

Get information about an action.

=item * help <action>

Get help on how to use an action.

=item * join <channel> <password>

TODO

=item * part

TODO

=back

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Core

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Core> provides core functionality
for L<Convos::Plugin::Bot>.

=head1 ATTRIBUTES

=head2 bot

Holds a L<Convos::Plugin::Bot> object.

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head2 usage

See L<Convos::Plugin::Bot::Action/usage>.

=head1 METHODS

=head2 register

Will store C<$bot> in L</bot>.

=head2 reply

Can reply to one of the L</Commands> if sent in a private conversation.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
