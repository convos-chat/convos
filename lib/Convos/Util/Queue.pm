package Convos::Util::Queue;
use Mojo::Base -base;

use Mojo::Promise;
use Scalar::Util qw(weaken);

has delay => 0;

sub enqueue_p {
  my ($self, $name, $cb) = @_;
  my $p = Mojo::Promise->new;
  push @{$self->{queue}{$name}}, [$p, $self->size($name) && $self->delay];

  weaken $self;
  $p->then($cb)->then(sub { _dequeue($self, $name, 1) }, sub { _dequeue($self, $name, 2) });
  $self->_dequeue($name, 0);

  return $p;
}

sub size {
  my ($self, $name) = @_;
  return ($self->{pending}{$name} ? 1 : 0) + int @{$self->{queue}{$name} || []};
}

sub _dequeue {
  my ($self, $name, $next) = @_;
  return unless $self;    # In case object got destroyed

  delete $self->{pending}{$name} if $next;
  return if $self->{pending}{$name} || !(my $i = shift @{$self->{queue}{$name}});

  my $delay = $next < 2 && $i->[1];
  return $self->{pending}{$name}
    = $delay ? Mojo::Promise->timer($delay)->then(sub { $i->[0]->resolve }) : $i->[0]->resolve;
}

1;

=encoding utf8

=head1 NAME

Convos::Util::Queue - An EXPERIMENTAL queue

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 delay

  $num = $q->delay;
  $q   = $q->delay(4);

The number of seconds to wait before resolving the next item in the queue.

=head1 METHODS

=head2 enqueue_p

  $p = $q->enqueue_p(queue_name => $cb);
  $p = $q->enqueue_p(queue_name => sub { Mojo::Promise->resolve });
  $p = $q->enqueue_p(queue_name => sub { Mojo::Promise->reject });

Returns a L<Mojo::Promise> that will be resolved once the queue has reach that
point. Once resolved, the callback will be called, and the next item in the
queue will be dequeued once the callback has completed.

=head2 size

  $int = $q->size('queue_name');

Returns the size of a named queue.

=head1 SEE ALSO

L<Convos>

=cut
