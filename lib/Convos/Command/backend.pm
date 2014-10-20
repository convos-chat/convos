package Convos::Command::backend;

=head1 NAME

Convos::Command::backend - Start convos backend

=head1 DESCRIPTION

This command is used to start/stop/restart the convos backend.

=cut

use Mojo::Base 'Mojolicious::Command';
use File::Spec;

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 pid_file

Path to pid file.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Start the Convos connection backend.\n";
has pid_file    => sub { $ENV{CONVOS_PID_FILE} || File::Spec->catfile(File::Spec->tmpdir, 'convos-backend.pid') };
has usage       => <<"EOF";
Usage: $0 backend {start|stop|restart}
EOF

=head1 METHODS

=head2 check_pid

  $pid = $self->check_pid;

Returns the pid of the backend if running.

=cut

sub check_pid {
  my $file = shift->pid_file;
  return undef unless open my $handle, '<', $file;
  my $pid = <$handle>;
  chomp $pid;

  # Running
  return $pid if $pid && kill 0, $pid;

  # Not running
  unlink $file if -w $file;
  return undef;
}

=head2 ensure_pid_file

  $self->ensure_pid_file;

Make sure the pid file exists.

=cut

sub ensure_pid_file {
  my $self = shift;

  # Check if PID file already exists
  return if -e (my $file = $self->pid_file);

  # Create PID file
  $self->app->log->info(qq{Creating process id file "$file".});
  die qq{Can't create process id file "$file": $!} unless open my $handle, '>', $file;
  chmod 0644, $handle;
  print $handle $$;
}

=head2 run

Will start/stop/restart the backend.

=cut

sub run {
  my $self = shift;
  my $action = shift || 'usage';

  if (my $method = $self->can("_action_$action")) {
    $ENV{MOJO_MODE} ||= '';
    die qq(MOJO_MODE need to be set to either "production" or "development".\n)
      unless $ENV{MOJO_MODE} =~ /^(production|development)$/;
    $self->$method(@_);
  }
  else {
    print $self->usage;
  }

  return 0;
}

sub _action_restart {
  my $self = shift;

  if ($self->stop) {
    $self->start;
  }
}

sub _action_start {
  my ($self, @args) = @_;
  my $app  = $self->app;
  my $loop = Mojo::IOLoop->singleton;

  if (my $pid = $self->check_pid) {
    print "Convos backend is already running ($pid)\n";
    return;
  }

  $self->ensure_pid_file;

  $SIG{QUIT} = sub {
    $app->log->info('Gracefully stopping backend...');
    $loop->max_connnections(0);
  };

  Scalar::Util::weaken($self);
  Mojo::IOLoop->recurring(sub { $self->ensure_pid_file });

  $app->core->start;
  $app->log->info('Starting convos backend');
  $loop->start;
}

sub _action_stop {
  my ($self, @args) = @_;
  my $pid = $self->check_pid;

  unless (defined $pid) {
    print "Convos backend is already stopped\n";
    return 1;
  }

  print "Stopping backend pid $pid\n";
  kill $pid;
  waitpid $pid, 0;
}

sub DESTROY {
  my $self = shift;

  if (my $file = $self->pid_file) {
    unlink $file if -w $file;
  }
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
