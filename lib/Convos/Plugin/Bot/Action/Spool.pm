package Convos::Plugin::Bot::Action::Spool;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use Convos::Util::YAML qw(decode_yaml);
use Mojo::File         qw(path);

has description => 'Send messages from spool directory on server.';
has _dir        => undef;

sub register {
  my ($self, $bot, $config) = @_;
  my $user = $bot->user;

  $self->_dir(path($ENV{CONVOS_BOT_SPOOL_DIR} || $user->core->home->child($user->email, 'spool')));
  $self->_dir->make_path unless -d $self->_dir;

  Scalar::Util::weaken($self);
  Mojo::IOLoop->recurring(
    ($ENV{CONVOS_BOT_SPOOL_INTERVAL} || 1) => sub { $self and $self->_check_for_message($user); });
}

sub _check_for_message {
  my ($self, $user) = @_;

  my $files = $self->_dir->list->sort;
  my $guard = 50;
  while (my $file = pop @$files) {
    my $message    = decode_yaml($file->slurp);
    my $connection = $user->get_connection($message->{connection_id});
    next unless $connection and $connection->state eq 'connected';
    $connection->send_p(@$message{qw(conversation_id message)})->catch(sub {
      $user->core->log->warn(sprintf 'Bot send "%s" to "%s/%s": %s',
        @$message{qw(message connection_id conversation_id)}, pop);
    });
    unlink $file;
    return unless --$guard;    # Make sure we do not block for too long
  }
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Spool - Send messages found in a spool directory

=head1 DESCRIPTION

This action will send messages found in a spool directory. Default directory is:

  $CONVOS_HOME/your_bot@example.com/spool

The files are sorted by name and not by date. The reason for this is that you
might want to prioritize certain messages.

=head2 File format

The file must be a valid YAML file. Example message file:

  ---
  connection_id: irc-libera
  conversation_id: "#convos"
  message: Some message

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head1 METHODS

=head2 register

Sets up an recurring timer that checks for new messages. By default the bot can only
send one message per second.

=head1 SEE ALSO

L<Convos::Plugin::Bot>, L<Convos>.

=cut
