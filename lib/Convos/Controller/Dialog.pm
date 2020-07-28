package Convos::Controller::Dialog;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Date 'dt';
use Mojo::JSON qw(false true);

sub last_read {
  my $self      = shift->openapi->valid_input or return;
  my $dialog    = $self->backend->dialog({});
  my $last_read = Mojo::Date->new->to_datetime;

  unless ($dialog) {
    return $self->reply->errors([],                  401) unless $self->backend->user;
    return $self->reply->errors('Dialog not found.', 404);
  }

  $dialog->last_read($last_read);
  $self->stash('connection')->save_p->then(sub {
    $self->render(openapi => {last_read => $last_read});
  });
}

sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);
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
    return $self->reply->errors([], 401) unless $self->backend->user;
    return $self->render(openapi => {messages => [], end => true});
  }

  $query{$_} = $self->param($_)
    for grep { defined $self->param($_) } qw(after before level limit match);
  $query{limit} ||= $query{after} && $query{before} ? 200 : 60;
  $query{limit} = 200 if $query{limit} > 200;

  # Input check
  if ($query{after} and $query{before}) {
    return $self->reply->errors([['Must be before "/after".', '/before']], 400)
      if dt($query{after}) > dt($query{before});
    return $self->reply->errors([['Must be less than "/after" - 12 months.', '/before']], 400)
      if abs(dt($query{after}) - dt($query{before})) > 86400 * 365;
  }

  return $dialog->messages_p(\%query)->then(sub {
    my $res = shift;
    $self->render(
      openapi => {
        end         => $res->{end} // true,
        messages    => $res->{messages},
        n_messages  => int(@{$res->{messages}}),
        n_requested => $res->{limit},
      }
    );
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

See L<https://convos.chat/api.html#op-post--connection--connection_id--dialog--dialog_id--read>

=head2 list

See L<https://convos.chat/api.html#op-get--dialogs>

=head2 messages

See L<https://convos.chat/api.html#op-get--connection--connection_id--dialog--dialog_id--messages>

=head1 SEE ALSO

L<Convos>.

=cut
