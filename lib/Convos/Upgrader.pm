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

=item * L<Convos::Upgrader::v0_3003>

=item * L<Convos::Upgrader::v0_3004>

=item * L<Convos::Upgrader::v0_3005>

=back

=cut

use utf8 ();
use Mojo::Base -base;
use File::Spec::Functions qw( catfile tmpdir );
use Mojo::Loader;
use Mojo::Redis;

=head1 ATTRIBUTES

=head2 steps

Holds a list of C<Convos::Upgrader::v_xxx> objects that will be used to
upgrade L<Convos>. This attribute is initialized by L</running_latest>.

=head2 redis

Holds a L<Mojo::Redis> object. Required in constructor to avoid migrating the
wrong database.

=head2 version

Holds the current version. This attribute is initialized by L</running_latest>.

=cut

has steps => sub { [] };
has redis => undef;
has version => 0;
has _raw_redis => sub { Mojo::Redis->new(server => shift->redis->server, encoding => ''); };

=head1 METHODS

=head2 run

  $self->run(sub {
    my($self, $err) = @_;
  });

This method will check the current database version and run upgrade steps
to the wanted version. C<$err> will be false if everything went well.

=cut

sub run {
  my ($self, $cb) = @_;
  my ($guard, $error);

  Scalar::Util::weaken($self);
  $guard = $self->redis->once(error => sub { $error++; $self->$cb($_[1]); });
  $self->{stepped} = 0;
  $self->running_latest(
    sub {
      $self->_next(
        sub {
          my ($self, $err) = @_;
          $self->redis->unsubscribe($guard);
          $self->$cb($err) unless $error;
        }
      );
    }
  );
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
  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->scard('connections', $delay->begin);
    },
    sub {
      my ($delay, $existing) = @_;
      $existing and return $self->redis->get('convos:version', $delay->begin);

      # nothing to upgrade, but let us insert defaults
      $self->steps($self->_build_steps(0));
      $self->_next(sub { $self->steps([]); $self->$cb(1); });
    },
    sub {
      my ($delay, $version) = @_;
      $self->steps($self->_build_steps($version || 0));
      $self->$cb(@{$self->steps} ? 0 : 1);
    },
  );

  $self;
}

sub _build_steps {
  my ($self, $version) = @_;
  my $loader = Mojo::Loader->new;
  my ($e, @steps);

  for my $class (sort @{$loader->search('Convos::Upgrader')}) {
    my $v = $self->_version_from_class($class) or next;
    $self->version($v);
    $v <= $version and next;
    $e = $loader->load($class) and die "[error] Could not load $class: $@";
    push @steps, $class->new(redis => $self->redis, version => $v);
  }

  return \@steps;
}

sub _next {
  my ($self, $cb) = @_;
  my $step = shift @{$self->steps};

  unless ($step) {
    $self->redis->set('convos:version', $self->version, sub { $self->$cb('') });
    return;
  }

  $self->{stepped}++;
  $step->run(
    sub {
      my ($step, $err) = @_;
      return $self->$cb("Step @{$step->version} failed: $err") if $err;
      return $self->_next($cb);
    }
  );
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
