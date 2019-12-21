package Convos::Controller::Dialog;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::JSON qw(false true);

sub last_read {
  my $self      = shift->openapi->valid_input or return;
  my $dialog    = $self->backend->dialog({});
  my $last_read = Mojo::Date->new->to_datetime;

  unless ($dialog) {
    return $self->unauthorized unless $self->backend->user;
    return $self->render(openapi => E('Dialog not found.'), status => 404);
  }

  $dialog->last_read($last_read);
  $self->stash('connection')->save_p->then(sub {
    $self->render(openapi => {last_read => $last_read});
  });
}

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my @dialogs;

  my @p;
  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $dialog (sort { $a->id cmp $b->id } @{$connection->dialogs}) {
      push @dialogs, $dialog;
      push @p,       $dialog->calculate_unread_p;
    }
  }

  push @p, Mojo::Promise->resolve unless @p;
  Mojo::Promise->all(@p)->then(sub {
    $self->render(openapi => {dialogs => \@dialogs});
  });
}

sub messages {
  my $self   = shift->openapi->valid_input or return;
  my $dialog = $self->backend->dialog({});
  my %query;

  unless ($dialog) {
    return $self->unauthorized unless $self->backend->user;
    return $self->render(openapi => {messages => [], end => true});
  }

  # TODO:
  $query{$_} = $self->param($_)
    for grep { defined $self->param($_) } qw(after before level limit match);
  $query{limit} ||= 60;
  $query{limit} = 200 if $query{limit} > 200;    # TODO: is this a good max?

  return $dialog->messages_p(\%query)->then(sub {
    my $messages = shift;
    $self->render(
      openapi => {messages => $messages, end => @$messages < $query{limit} ? true : false});
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Dialog - Convos dialogs

=head1 DESCRIPTION

L<Convos::Controller::Dialog> is a L<Mojolicious::Controller> with
dialog related actions.

=head1 METHODS

=head2 last_read

See L<Convos::Manual::API/setDialogLastRead>.

=head2 list

See L<Convos::Manual::API/listDialogs>.

=head2 messages

See L<Convos::Manual::API/messagesForDialog>.

=head1 SEE ALSO

L<Convos>.

=cut
