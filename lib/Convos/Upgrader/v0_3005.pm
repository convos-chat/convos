package Convos::Upgrader::v0_3005;

=head1 NAME

Convos::Upgrader::v0_3005 - Cleanup instructions to version 0.3005

=head1 DESCRIPTION

This upgrade step will remove junk from the database.

=cut

use Mojo::Base 'Convos::Upgrader';

=head1 METHODS

=head2 run

Called by L<Convos::Upgrader>.

=cut

sub run {
  my ($self, $cb) = @_;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->keys('connection:*', $delay->begin);
      $redis->keys('avatar:*',     $delay->begin);
    },
    sub {
      my ($delay, $c_keys, $a_keys) = @_;
      $redis->del(@$c_keys, $delay->begin) if @$c_keys;
      $redis->del(@$a_keys, $delay->begin) if @$a_keys;
      $delay->begin->();    # guard
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
