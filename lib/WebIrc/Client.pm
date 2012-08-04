package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use feature 'state';
use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 goto_view

Used to jump from C</chat> to C</:server/:target> using session
information.

=cut

sub goto_view {
  my $self = shift;

  $self->redirect_to(client_view => {
    target => $self->session->{'target'} || '#mojo',
    server => $self->session->{'server'} || 'irc.perl.org',
  });
}

=head2 view

Will serve JSON data used to render the main IRC client information.

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

  # TODO Retrieve data from backend
  $self->render_json({});
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
