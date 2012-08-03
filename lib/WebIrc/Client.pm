package WebIrc::Client;

=head1 NAME

WebIrc::Client

=cut

use feature 'state';
use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 goto_view

=cut

sub goto_view {
  my $self = shift;

  $self->redirect_to(client_view => {
    target => $self->session->{'target'} || '#mojo',
    server => $self->session->{'server'} || 'irc.perl.org',
  });
}

=head2 view

=cut

sub view {
  my $self = shift;

  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
  $self->respond_to(
    html => sub {},
    json => \&_view_json,
  );
}

sub _view_json {
  my $self = shift;

  if($ENV{'NO_REDIS'}) {
    state $data = eval do { local $/; readline DATA } or warn $@;
    $self->render_json($data);
  }

  # TODO
  $self->render_json({});
}

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
__DATA__
{
nick => 'test123',
targets => [
  {
    name => '#mojo',
    className => 'active',
  },
  {
    name => '#wirc',
    className => '',
  },
],
messages => [
  {
    text => 'Connecting to #mojo...',
    sender => '[server]',
    className => 'icon-comment',
  }
],
nick_list => [
  {
    name => 'batman',
    mode => '',
  }
],
};
