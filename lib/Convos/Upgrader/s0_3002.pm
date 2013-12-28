package Convos::Upgrader::s0_3002;

=head1 NAME

Convos::Upgrader::s0_3002 - Upgrade instructions to version 0.3002

=head1 DESCRIPTION

This is currently a dummy module to make the unittest do anything.

=cut

use Mojo::Base 'Convos::Upgrader';

sub _run {
  my $self = shift;

  $self->emit('finish');
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
