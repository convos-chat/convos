package Convos::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::JSON qw(false true);
use Mojo::Util 'url_unescape';
use Time::Piece ();

sub messages {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;
  my %query = $self->_make_query;

  return $self->render(openapi => {messages => [], end => true}) unless $query{match};

  my $cid         = $self->param('connection_id');
  my @connections = grep $_, $cid ? ($user->get_connection($cid)) : @{$user->connections};
  return $self->render(openapi => E('Connection not found.'), status => 404)
    if $cid and !@connections;

  my $did     = url_unescape $self->param('dialog_id') || '';
  my @dialogs = grep $_, map { $did ? ($_->get_dialog($did)) : @{$_->dialogs} } @connections;
  return $self->render(openapi => E('Dialog not found.'), status => 404) if $did and !@dialogs;
  return $self->render(openapi => {messages => [], end => true}) unless @dialogs;

  my @p = map { (Mojo::Promise->resolve($_), $_->messages_p(\%query)) } @dialogs;
  return Mojo::Promise->all(@p)->then(sub {
    my @res;

    while (@_) {
      my ($dialog, $messages) = map { $_->[0] } shift @_, shift @_;
      push @res,
        map { +{%$_, connection_id => $dialog->connection->id, dialog_id => $dialog->id} }
        @$messages;
    }

    @res = sort { $a->{ts} cmp $b->{ts} } @res;

    $self->render(openapi => {messages => \@res, end => false});
  });
}

sub _default_after {
  my $tp = Time::Piece->new;
  $tp = $tp - 86400 * 90;    # 90 days back
  return $tp->datetime;
}

sub _make_query {
  my $self = shift;

  my %query = (
    after  => $self->param('after') || $self->_default_after,
    before => $self->param('before'),
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

See L<Convos::Manual::API/searchMessages>.

=head1 SEE ALSO

L<Convos>.

=cut
