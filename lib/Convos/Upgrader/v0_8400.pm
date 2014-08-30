package Convos::Upgrader::v0_8400;

=head1 NAME

Convos::Upgrader::v0_8400 - Upgrade instructions to version 0.8400

=head1 DESCRIPTION

This upgrade step will remove predefined networks from the database.

=cut

use Mojo::Base 'Convos::Upgrader';

=head1 METHODS

=head2 run

Called by L<Convos::Upgrader>.

=cut

sub run {
  my ($self, $cb) = @_;
  my $delay = $self->redis->ioloop->delay;
  my $guard = $delay->begin;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->smembers('irc:networks', $delay->begin);
    },
    sub {
      my ($delay, $networks) = @_;
      $self->redis->del("irc:network:$_", $delay->begin) for @{$networks || []};
      $self->redis->del('irc:networks', $delay->begin);
      $self->redis->del('irc:default:network', $delay->begin);
    },
    sub {
      my ($delay, @deleted) = @_;
      $self->$cb('');
    },
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
