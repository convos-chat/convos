package Convos::Controller::Conversation;
use Mojo::Base 'Mojolicious::Controller', -async_await;

use Convos::Date 'dt';
use Mojo::Util qw(url_unescape);

async sub mark_as_read {
  my $self         = shift->openapi->valid_input or return;
  my $user         = await $self->user->load_p   or return $self->reply->errors([], 401);
  my $conversation = $self->_conversation($user)
    or return $self->reply->errors('Conversation not found.', 404);

  $conversation->notifications(0)->unread(0);
  await $self->stash('connection')->save_p;
  $self->render(openapi => {});
}

async sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = await $self->user->load_p   or return $self->reply->errors([], 401);
  my @conversations;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $conversation (sort { $a->id cmp $b->id } @{$connection->conversations}) {
      push @conversations, $conversation;
    }
  }

  $self->render(openapi => {conversations => \@conversations});
}

async sub messages {
  my $self         = shift->openapi->valid_input or return;
  my $user         = await $self->user->load_p   or return $self->reply->errors([], 401);
  my $conversation = $self->_conversation($user)
    or return $self->reply->errors('Conversation not found.', 404);

  my %query;
  $query{$_} = $self->param($_)
    for grep { defined $self->param($_) } qw(after around before level limit match);
  $query{limit} ||= $query{after} && $query{before} ? 200 : 60;
  $query{limit} = 200 if $query{limit} > 200;

  # Input check
  if ($query{after} and $query{before}) {
    return $self->reply->errors([['Must be before "/after".', '/before']], 400)
      if dt($query{after}) > dt($query{before});
    return $self->reply->errors([['Must be less than "/after" - 12 months.', '/before']], 400)
      if abs(dt($query{after}) - dt($query{before})) > 86400 * 365;
  }

  $self->render(openapi => await $conversation->messages_p(\%query));
}

sub _conversation {
  my ($c, $user) = @_;
  return unless my $connection = $user->get_connection($c->stash('connection_id'));

  my $conversation_id = url_unescape $c->stash('conversation_id');
  my $conversation
    = $conversation_id ? $connection->get_conversation($conversation_id) : $connection->messages;
  return $c->stash(connection => $connection, conversation => $conversation)->stash('conversation');
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Conversation - Convos conversations

=head1 DESCRIPTION

L<Convos::Controller::Conversation> is a L<Mojolicious::Controller> with
conversation related actions.

=head1 METHODS

=head2 list

See L<https://convos.chat/api.html#op-get--conversations>

=head2 mark_as_read

See L<https://convos.chat/api.html#op-post--connection--connection_id--conversation--conversation_id--read>

=head2 messages

See L<https://convos.chat/api.html#op-get--connection--connection_id--conversation--conversation_id--messages>

=head1 SEE ALSO

L<Convos>.

=cut
