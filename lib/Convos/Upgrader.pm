package Convos::Upgrader;

=head1 NAME

Convos::Upgrader - Apply changes from one convos version to another

=head1 DESCRIPTION

This class can to upgrade the convos database from one version to another.

Before running the upgrade, we try to do a backup of the current redis
data related to convos. If that fail, we do not continue.

The upgrade is done by fetching the current version that is stored in the
database and run the steps from the version after and up to the lastest
version available. Each step is described in the L<Convos::Upgrader|/STEPS>
namespace.

It is possible to set the environment variable "CONVOS_FORCE_UPGRADE"
if you want to skip the backup step.

=head1 STEPS

=over 4

=item * L<Convos::Upgrader::v0_3002>

=back

=cut

use utf8 ();
use Mojo::Base 'Mojo::EventEmitter';
use File::Spec::Functions qw( catfile tmpdir );
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

=head2 steps

Holds a list of C<Convos::Upgrader::v_xxx> objects that will be used to
upgrade L<Convos>.

=head2 redis

Holds a L<Mojo::Redis> object. Required in constructor to avoid migrating the
wrong database.

=head2 version

Holds the target version, once L</run> has figured it out.

=cut

has steps => sub { shift->_build_steps; };
has redis => undef;
has version => 0;
has _raw_redis => sub { Mojo::Redis->new(server => shift->redis->server, encoding => ''); };

=head1 METHODS

=head2 run

This method will check the current database version and run upgrade steps
to the wanted version.

=cut

sub run {
  my $self = shift;

  $self->redis->get(
    'convos:version',
    sub {
      my ($redis, $current) = @_;
      $self->version($current || 0);
      @{$self->steps} ? $self->_next : $self->_finish;
    }
  );

  $self;
}

=head2 running_latest

  $self = $self->running_latest(sub {
    my($self, $bool) = @_;
  });

Check if the latest version of the Convos database is in effect.

=cut

sub running_latest {
  my ($self, $cb) = @_;

  Scalar::Util::weaken($self);
  $self->redis->get(
    'convos:version' => sub {
      my ($redis, $version) = @_;
      my $steps = $self->_build_steps($version || 0);
      $self->$cb(@$steps ? 0 : 1);
    }
  );

  $self;
}

sub _build_steps {
  my $self    = shift;
  my $version = shift || $self->version;
  my $loader  = Mojo::Loader->new;
  my ($e, @steps);

  for my $class (sort @{$loader->search('Convos::Upgrader')}) {
    my $v = $self->_version_from_class($class) or next;
    $v <= $version and next;
    $e = $loader->load($class) and $self->emit(error => $e) and next;
    push @steps, $class->new(redis => $self->redis, version => $v);
    $self->{version} = $v;
  }

  return \@steps;
}

sub _finish {
  my $self = shift;

  return $self->emit(finish => "Database schema has latest version.") unless $self->version;
  return $self->redis->set(
    'convos:version',
    $self->version,
    sub {
      $self->emit(finish => "Upgraded database to $self->{version} through $self->{stepped} steps.");
    }
  );
}

sub _next {
  my $self = shift;
  my $step = shift @{$self->{steps}} or return $self->_finish;

  $step->on(finish => sub { $self->{stepped}++; $self->_next; });
  $step->on(error => sub { $self->error(pop); });
  $step->run;
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
