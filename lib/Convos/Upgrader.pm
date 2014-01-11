package Convos::Upgrader;

=head1 NAME

Convos::Upgrader - Apply changes from one convos version to another

=head1 DESCRIPTION

This class can to upgrade the convos database from one version to another.

The upgrade is done by fetching the current version that is stored in the
database and run the steps from the version after and up to the lastest
version available. Each step is described in the L<Convos::Upgrader|/STEPS>
namespace.

=head1 STEPS

=over 4

=item * L<Convos::Upgrader::v0_3002>

=back

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Loader;
use Mojo::Redis;

=head1 EVENTS

=head2 error

  $self->on(error => sub { my($self, $msg) = @_; });

Emitted if the upgrade fail.

=head2 finish

  $self->on(finish => sub { my($self, $msg) = @_; });

Emitted when the upgrade was completed.

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object. Required in constructor to avoid migrating the
wrong database.

=cut

has redis => undef;
has _loader => sub { Mojo::Loader->new };

=head1 METHODS

=head2 run

This method will check the current database version and run upgrade steps
to the wanted version.

=cut

sub run {
  my($self, $cb) = @_;

  $self->redis->get('convos:version', sub {
    my($redis, $current) = @_;
    $self->{steps} = $self->_steps($current);
    $self->_next;
  });

  $self;
}

sub _finish {
  my $self = shift;

  return $self->emit(finish => "Database schema has latest version.") unless $self->{version};
  return $self->redis->set('convos:version', $self->{version}, sub {
    $self->emit(finish => "Upgraded database to $self->{version} through $self->{stepped} steps.");
  });
}

sub _next {
  my $self = shift;
  my $step = shift @{ $self->{steps} } or return $self->_finish;

  $step->on(finish => sub { $self->{stepped}++; $self->_next; });
  $step->on(error => sub { $self->error(pop); });
  $step->run;
}

sub _steps {
  my $self = shift;
  my $current = shift || 0;
  my $loader = $self->_loader;
  my @steps;

  for my $class (sort @{ $loader->search('Convos::Upgrader') }) {
    my $v = $self->_version_from_class($class) or next;
    my $e;
    $v <= $current and next;
    $e = $loader->load($class) and $self->emit(error => $e) and next;
    push @steps, $class->new(redis => $self->redis, version => $v);
    $self->{version} = $v;
  }

  return \@steps;
}

sub _version_from_class {
  my $v = $_[1] =~ /::v(\d.*)/ ? $1 : 0;
  $v =~ s/_/\./;
  $v;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
