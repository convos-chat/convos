package Convos::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(false true);
use Mojo::Util 'url_unescape';
use Time::Piece ();

use constant DEFAULT_AFTER => $ENV{CONVOS_DEFAULT_SEARCH_AFTER} || 86400 * 90;

sub messages {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);
  my %query = $self->_make_query;

  return $self->render(openapi => {messages => [], end => true}) unless $query{match};

  my $cid         = $self->param('connection_id');
  my @connections = grep $_, $cid ? ($user->get_connection($cid)) : @{$user->connections};
  return $self->reply->errors('Connection not found.', 404) if $cid and !@connections;

  my $did     = url_unescape $self->param('dialog_id') || '';
  my @dialogs = grep $_, map { $did ? ($_->get_dialog($did)) : @{$_->dialogs} } @connections;
  return $self->reply->errors('Dialog not found.', 404) if $did and !@dialogs;
  return $self->render(openapi => {messages => [], end => true}) unless @dialogs;

  my @p = map { (Mojo::Promise->resolve($_), $_->messages_p(\%query)) } @dialogs;
  return Mojo::Promise->all(@p)->then(sub {
    my @messages;

    while (@_) {
      my ($dialog, $res) = map { $_->[0] } shift @_, shift @_;
      push @messages,
        map { +{%$_, connection_id => $dialog->connection->id, dialog_id => $dialog->id} }
        @{$res->{messages}};
    }

    @messages = sort { $a->{ts} cmp $b->{ts} } @messages;

    $self->render(openapi => {messages => \@messages, end => false});
  });
}

sub _make_query {
  my $self = shift;
  my $tp   = Time::Piece->new;

  my %query = (
    after  => $self->param('after') || ($tp - DEFAULT_AFTER)->datetime,
    before => $self->param('before'),
    from   => $self->param('from'),
    limit  => $self->param('limit') || 60,
    match  => $self->param('match'),
  );

  return %query;
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
