package Convos::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Date qw(dt);
use Mojo::JSON qw(false true);
use Mojo::Util qw(trim);

use constant DEFAULT_AFTER => $ENV{CONVOS_DEFAULT_SEARCH_AFTER} || 86400 * 365;

sub messages {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);

  my $query = $self->_make_query;
  return $self->render(openapi => {messages => [], end => true}) if 2 >= keys %$query;

  my $cid         = delete $query->{connection_id};
  my @connections = grep {$_} $cid ? $user->get_connection($cid) : @{$user->connections};
  return $self->reply->errors('Connection not found.', 404) if $cid and !@connections;

  $cid = delete $query->{conversation_id};
  my @conversations
    = grep {$_} map { $cid ? ($_->get_conversation($cid)) : @{$_->conversations} } @connections;
  return $self->render(openapi => {messages => [], end => true}) unless @conversations;

  my @p = map { (Mojo::Promise->resolve($_), $_->messages_p($query)) } @conversations;
  return Mojo::Promise->all(@p)->then(sub {
    my @messages;

    while (@_) {
      my ($conversation, $res) = map { $_->[0] } shift @_, shift @_;
      push @messages, map {
        +{
          %$_,
          connection_id   => $conversation->connection->id,
          conversation_id => $conversation->id
        }
      } @{$res->{messages}};
    }

    @messages = sort { $a->{ts} cmp $b->{ts} } @messages;

    $self->render(openapi => {messages => \@messages, end => false});
  });
}

sub _make_query {
  my $self = shift;

  my %query;
  $query{after} = $self->param('after') || (dt() - DEFAULT_AFTER)->datetime;
  $query{limit} = $self->param('limit') || 60;
  $query{$_}    = $self->param($_)
    for grep { $self->param($_) } qw(before connection_id conversation_id from);

  my $match = $self->param('match') // '';
  my (@conversation_id, @from);
  $match =~ s!(\#\S+)!{push(@conversation_id, $1), ''}!e unless $query{conversation_id};
  $match =~ s!\@(\S+)!{push(@from, $1), ''}!e            unless $query{from};

  $query{conversation_id} = $conversation_id[-1] if @conversation_id;
  $query{from}            = $from[-1]            if @from;
  $query{match}           = trim $match          if length $match;

  return \%query;
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Search - Search for messages

=head1 METHODS

=head2 messages

See L<https://convos.chat/api.html#op-get--search>

=head1 SEE ALSO

L<Convos>.

=cut
