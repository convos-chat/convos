package Convos::Controller::Dialog;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::JSON qw(false true);

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my @dialogs;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $dialog (sort { $a->id cmp $b->id } @{$connection->dialogs}) {
      push @dialogs, $dialog;
    }
  }

  $self->render(openapi => {dialogs => \@dialogs});
}

sub messages {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $connection = $user->get_connection($self->stash('connection_id'))
    or return $self->render(openapi => E('Connection not found.'), status => 404);
  my $dialog = $connection->get_dialog($self->stash('dialog_id'))
    or return $self->render(openapi => E('Dialog not found.'), status => 404);
  my %query;

  # TODO:
  $query{$_} = $self->param($_)
    for grep { defined $self->param($_) } qw(after before level limit match);
  $query{limit} ||= 60;
  $query{limit} = 200 if $query{limit} > 200;    # TODO: is this a good max?

  $self->delay(
    sub { $dialog->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      $self->render(
        openapi => {messages => $messages, end => @$messages < $query{limit} ? true : false});
    },
  );
}

sub participants {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my $connection = $user->get_connection($self->stash('connection_id'));

  unless ($connection) {
    return $self->render(openapi => E('Connection not found.'), status => 404);
  }

  $self->delay(
    sub { $connection->participants($self->stash('dialog_id'), shift->begin); },
    sub {
      my ($delay, $err, $participants) = @_;
      return $self->render(openapi => E($err), status => 500) if $err;
      return $self->render(openapi => {participants => $participants});
    },
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Dialog - Convos dialogs

=head1 DESCRIPTION

L<Convos::Controller::Dialog> is a L<Mojolicious::Controller> with
dialog related actions.

=head1 METHODS

=head2 list

See L<Convos::Manual::API/listDialogs>.

=head2 messages

See L<Convos::Manual::API/messagesForDialog>.

=head2 participants

See L<Convos::Manual::API/participantsInDialog>.

=head1 SEE ALSO

L<Convos>.

=cut
