package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

my $JSON = Mojo::JSON->new;
my $dummy_json = eval do { local $/; readline DATA };

=head1 METHODS

=head2 setup

=cut

sub setup {
  my $self = shift;

  if($self->param('server') and $self->param('target')) {
    $self->redirect_to('view',
      server => $self->param('server'),
      target => $self->param('target'),
    );
  }
}

=head2 view

Used to render the main IRC client view.
Can serve both HTML and JSON.

=cut

sub view {
  my $self = shift;

  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
  $self->respond_to(
    json => sub {
      my $self = shift;
      $self->render_json($dummy_json);
    },
    any => sub {
      $self->stash($_ => $dummy_json->{$_}) for keys %$dummy_json;
    },
  );
}

=head2 socket

TODO

=cut

sub socket {
  my $self = shift;
  my $log = $self->app->log;

  # try to avoid inactivity timeout
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

  $self->on(finish => sub {
    $log->debug("Client finished, need to drop some connections..?");
  });
  $self->on(message => sub {
    $log->debug("Got message from client: $_[1]");
    my $self = shift;
    my $data = $JSON->decode(shift);
    # TODO: Use $data->{'command'};
  });
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
__DATA__
{
nick => 'test123',
servers => [
  {
    name => 'irc.perl.org',
    targets => [
      {
        name => '#mojo',
      },
      {
        name => '#wirc',
      },
    ],
  },
],
messages => [
  {
    message => 'Connecting to #mojo...',
    sender => '&irc.perl.org',
  }
],
nick_list => [
  {
    name => 'batman',
    mode => '',
  }
],
};
