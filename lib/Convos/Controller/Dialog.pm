package Convos::Controller::Dialog;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @dialogs;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $dialog (sort { $a->id cmp $b->id } @{$connection->dialogs}) {
      push @dialogs, $dialog;
    }
  }

  $self->$cb({dialogs => \@dialogs}, 200);
}

sub messages {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id}) or return $self->$cb({}, 404);
  my $dialog     = $connection->get_dialog($args->{dialog_id})   or return $self->$cb({}, 404);
  my %query;

  # TODO:
  $query{$_} = $args->{$_} for grep { defined $args->{$_} } qw(after before level limit match);

  $self->delay(
    sub { $dialog->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      $self->$cb({messages => $messages}, 200);
    },
  );
}

sub participants {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id});

  unless ($connection) {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  }

  $self->delay(
    sub { $connection->participants($args->{dialog_id}, shift->begin); },
    sub {
      my ($delay, $err, $participants) = @_;
      return $self->$cb({participants => $participants}, 200) unless $err;
      return $self->$cb($self->invalid_request($err), 500);
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
