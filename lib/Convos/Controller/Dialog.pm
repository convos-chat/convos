package Convos::Controller::Dialog;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'ce';
use Mojo::JSON qw(false true);

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @dialogs;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $dialog (sort { $a->id cmp $b->id } @{$connection->dialogs}) {
      push @dialogs, $dialog;
    }
  }

  $self->$cb({data => {dialogs => \@dialogs}});
}

sub messages {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id})
    or return $self->$cb(ce 'Not found.', '/connection_id', 404);
  my $dialog = $connection->get_dialog($args->{dialog_id})
    or return $self->$cb(ce 'Not found.', '/dialog_id', 404);
  my %query;

  # TODO:
  $query{$_} = $args->{$_} for grep { defined $args->{$_} } qw(after before level limit match);
  $query{limit} ||= 60;
  $query{limit} = 200 if $query{limit} > 200;    # TODO: is this a good max?

  $self->delay(
    sub { $dialog->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      $self->$cb(
        {data => {messages => $messages, end => @$messages < $query{limit} ? true : false}});
    },
  );
}

sub participants {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->get_connection($args->{connection_id});

  unless ($connection) {
    return $self->$cb(ce 'Connection not found.', '/connection_id', 404);
  }

  $self->delay(
    sub { $connection->participants($args->{dialog_id}, shift->begin); },
    sub {
      my ($delay, $err, $participants) = @_;
      return $self->$cb({data => {participants => $participants}}) unless $err;
      return $self->$cb(ce $err, '/', 500);
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

=head2 messages

=head2 participants

=head1 SEE ALSO

L<Convos>.

=cut
