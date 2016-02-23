package Convos::Controller::Conversation;
use Mojo::Base 'Mojolicious::Controller';

sub embed {
  my $self = shift;
  my $url  = $self->param('url');

  if (!$url or !$self->backend->user) {
    return $self->reply->not_found;
  }
  if (my $link = $self->app->_link_cache->get($url)) {
    return $self->respond_to(json => {json => $link}, any => {text => $link->to_embed});
  }

  $self->delay(
    sub { $self->embed_link($self->param('url'), shift->begin) },
    sub {
      my $link = $_[1];
      $self->app->_link_cache->set($url => $link);
      $self->respond_to(json => {json => $link}, any => {text => $link->to_embed});
    },
  );
}

sub join {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{connection_id}) or return $self->$cb({}, 404);

  $self->delay(
    sub { $connection->join_conversation($args->{body}{name}, shift->begin) },
    sub {
      my ($delay, $err, $room) = @_;
      return $self->$cb($self->invalid_request($err, '/body/name'), 400) if $err;
      $connection->save($delay->begin);
      $delay->pass($room);
    },
    sub {
      my ($delay, $err, $room) = @_;
      die $err if $err;
      $self->$cb($room->TO_JSON, 200);
    },
  );
}

sub list {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my @conversations;

  for my $connection (sort { $a->name cmp $b->name } @{$user->connections}) {
    for my $conversation (sort { $a->id cmp $b->id } @{$connection->conversations}) {
      push @conversations, $conversation->TO_JSON if $conversation->active;
    }
  }

  $self->$cb({conversations => \@conversations}, 200);
}

sub messages {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection   = $user->connection($args->{connection_id})           or return $self->$cb({}, 404);
  my $conversation = $connection->conversation($args->{conversation_id}) or return $self->$cb({}, 404);
  my %query;

  # TODO:
  $query{$_} = $args->{$_} for grep { defined $args->{$_} } qw( after before level limit match );

  $self->delay(
    sub { $conversation->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      $self->$cb({messages => $messages}, 200);
    },
  );
}

sub remove {
  my ($self, $args, $cb) = @_;
  die 'TODO';
  $self->$cb({message => ''}, 200);
}

sub send {
  my ($self, $args, $cb) = @_;
  my $user = $self->backend->user or return $self->unauthorized($cb);
  my $connection = $user->connection($args->{connection_id});

  unless ($connection) {
    return $self->$cb($self->invalid_request('Connection not found.'), 404);
  }

  $self->delay(
    sub { $connection->send($args->{conversation_id}, $args->{body}{command}, shift->begin); },
    sub {
      my ($delay, $err) = @_;
      return $self->$cb($args->{body}, 200) unless $err;
      return $self->$cb($self->invalid_request($err), 500);
    },
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Conversation - Convos conversations

=head1 DESCRIPTION

L<Convos::Controller::Conversation> is a L<Mojolicious::Controller> with
conversation related actions.

=head1 METHODS

=head2 embed

Used to expand a URL into markup, using L<Mojolicious::Plugin::LinkEmbedder>.

=head2 join

See L<Convos::Manual::API/joinConversation>.

=head2 list

See L<Convos::Manual::API/listConversations>.

=head2 messages

See L<Convos::Manual::API/messagesForConversation>.

=head2 remove

See L<Convos::Manual::API/removeConversation>.

=head2 send

See L<Convos::Manual::API/sendToConversation>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
