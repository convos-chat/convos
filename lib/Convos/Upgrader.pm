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

=head2 backup_file

Path to backup file. Default is "convos-redis-$timestamp.dump" in temp
directory or the C<CONVOS_BACKUP_FILE> environement variable.

=head2 redis

Holds a L<Mojo::Redis> object. Required in constructor to avoid migrating the
wrong database.

=cut

has backup_file => sub { $ENV{CONVOS_BACKUP_FILE} || catfile(tmpdir, "convos-redis-@{[time]}.dump") };
has redis => undef;
has _raw_redis => sub { Mojo::Redis->new(server => shift->redis->server, encoding => ''); };
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

    if($ENV{CONVOS_FORCE_UPGRADE}) {
      $self->_next;
    }
    else {
      $self->_backup(sub { $self->_next });
    }
  });

  $self;
}

sub _backup {
  my($self, $cb) = @_;
  my $max_keys = $ENV{CONVOS_MAX_DUMP_KEYS} ||= 10_000;
  my $backup_file = $self->backup_file;
  my($dumper, $keys);

  open my $BACKUP, '>', $backup_file or return $self->emit(error => "Could not create $backup_file: $!");

  $dumper = sub {
    my $redis = shift;
    my $key = shift @$keys;

    unless($key) {
      return $self->emit(error => "Could not close $backup_file: $!") unless close $BACKUP;
      return $self->$cb;
    }

    $redis->execute(dump => $key => sub {
      $_[1] =~ s!([^A-Za-z0-9._~,-])!{ sprintf '\x%02x', ord $1 }!ge;
      printf $BACKUP qq(RESTORE %s 0 "%s"\n), $key, $_[1];
      $dumper->($_[0]);
    });
  };

  $self->redis->dbsize(sub {
    return $self->emit(error => "Too many keys in database to do a dump. (>$max_keys)") if $_[1] > $max_keys;
    return $self->_raw_redis->keys('*' => sub { $keys = pop; $dumper->(shift); });
  });
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
