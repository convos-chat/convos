package Convos::Command::upgrade;

=head1 NAME

Convos::Command::upgrade - Upgrade Convos

=head1 DESCRIPTION

This command will stop any running backend and then upgrade the database.

IMPORTANT! BACKUP REDIS BEFORE RUNNING THE UPGRADE!

The upgrade process is tested, but you never know - and there is no
downgrade script.

Usage:
  $ script/convos upgrade --backup # optional
  $ script/convos upgrade --yes    # upgrade

The "--backup" will run the Redis commands below, which will block the
database while doing the backup. In addition it will use twice as much
disk space and it overwrite any existing "convos-backup.rdb"
database that exists.

  CONFIG SET dbfilename convos-backup.rdb
  SAVE
  CONFIG SET dbfilename dump.rdb

=cut

use Mojo::Base 'Mojolicious::Command';

$ENV{MOJO_MODE} ||= 'production';

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Upgrade the Convos database.\n";

has usage => <<"EOF";

This command will stop any running backend and then upgrade the database.

IMPORTANT! BACKUP REDIS BEFORE RUNNING THE UPGRADE!
IMPORTANT! MOJO_MODE is set to '$ENV{MOJO_MODE}'

The upgrade process is tested, but you never know - and there is no
downgrade script.

Usage:
  \$ $0 upgrade --backup # optional
  \$ $0 upgrade --yes    # upgrade

The "--backup" will run the Redis commands below, which will block the
database while doing the backup. In addition it will use twice as much
disk space and it overwrite any existing "convos-backup.rdb"
database that exists.

  CONFIG SET dbfilename convos-backup.rdb
  SAVE
  CONFIG SET dbfilename dump.rdb

EOF

=head1 METHODS

=head2 run

Will start the upgrade process.

=cut

sub run {
  my ($self, @args) = @_;
  my $backup  = grep { $_ eq '--backup' } @args;
  my $upgrade = grep { $_ eq '--yes' } @args;
  my $exit_value = 1;

  unless ($backup or $upgrade) {
    die $self->usage;
  }

  $ENV{CONVOS_MANUAL_BACKEND} = $ENV{CONVOS_SKIP_VERSION_CHECK} = 1;

  # force log to STDERR if attached to terminal
  if (-t STDERR) {
    $self->app->log->handle(\*STDERR);
  }

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->_stop_backend($delay->begin);
    },
    sub {
      my ($delay, $stopped) = @_;

      $delay->begin->(undef, $backup);
      $self->_backup($delay->begin) if $backup;
    },
    sub {
      my ($delay, $backup, $err) = @_;

      if ($err) {
        $self->app->log->error("Backup failed: $err");
        Mojo::IOLoop->stop;
      }
      elsif ($backup) {
        $self->app->log->info("Successfully backed up database.");
      }

      if ($upgrade) {
        $self->app->log->info("Upgrading database...");
        $self->app->upgrader->run($delay->begin);
      }
      else {
        $exit_value = $err ? 1 : 0;
        Mojo::IOLoop->stop;
      }
    },
    sub {
      my ($delay, $err) = @_;

      if ($err) {
        $self->app->log->error($err);
      }
      else {
        $self->app->log->info("Upgraded successfully. You can now start Convos.");
        $exit_value = 0;
      }
    },
  )->wait;

  return $exit_value;
}

sub _backup {
  my ($self, $cb) = @_;
  my $redis = $self->app->redis;
  my $filename;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->execute(qw( config get dbfilename ), $delay->begin);
    },
    sub {
      my ($delay, $res) = @_;
      $filename = ($res and $res->[1]) ? $res->[1] : 'dump.rdb';
      $redis->execute(qw( config set dbfilename ), 'convos-backup.rdb', $delay->begin);
    },
    sub {
      my ($delay, $success) = @_;
      $success or return $self->$cb("Could not set dbfilename in redis config");
      $redis->execute('save', $delay->begin);
    },
    sub {
      my ($delay, $success) = @_;
      $success or return $self->$cb("Could not save database to convos-backup.rdb");
      $redis->execute(qw( config set dbfilename ), $filename, $delay->begin);
    },
    sub {
      my ($delay, $success) = @_;
      $self->$cb($success ? "" : "Backup was created, but could not restore dbfilename in redis config");
    },
  );
}

sub _stop_backend {
  my ($self, $cb) = @_;
  my $redis  = $self->app->redis;
  my $killed = 0;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->get('convos:backend:pid', $delay->begin);
    },
    sub {
      my ($delay, $pid) = @_;

      # jhthorsen: This is blocking because I designed it like that.
      # Why? Because I do not want the IOLoop to do anything funky
      # while the backend is about to stop.
      while ($pid) {
        $killed++;
        $self->app->log->warn("Killing running backend ($pid)");
        kill 'QUIT', $pid or $pid = 0;
        sleep 1;
      }

      $redis->del('convos:backend:pid');
      $self->app->log->info("Backend is stopped");
      $self->$cb(1);
    },
  );
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
