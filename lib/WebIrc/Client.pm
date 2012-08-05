package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';

my $dummy_json = $ENV{'NO_REDIS'} ? eval do { local $/; readline DATA } : {};

=head1 METHODS

=head2 layout

Used to render the main IRC client layout.
Can serve both HTML and JSON.

=cut

sub layout {
  my $self = shift;

  $self->stash(logged_in => 1); # TODO: Remove this once login logic is written
  $self->respond_to(
    html => sub {},
    json => sub {
      my $self = shift;
      $self->render_json($dummy_json);
    },
  );
}

=head2 view

Will serve JSON data used to render the main IRC client information.

=cut

sub view {
  my $self = shift;

  $self->render_json($dummy_json);
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
        className => 'active',
      },
      {
        name => '#wirc',
        className => '',
      },
    ],
  },
],
messages => [
  {
    text => 'Connecting to #mojo...',
    sender => '&irc.perl.org',
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
