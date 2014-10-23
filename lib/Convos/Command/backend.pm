package Convos::Command::backend;

=head1 NAME

Convos::Command::backend - Start Convos backend

=head1 DESCRIPTION

This command is used to start the Convos backend.

=cut

use Mojo::Base 'Mojolicious::Command';
use Daemon::Control;

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Start the Convos connection backend.\n";
has usage       => <<"EOF";
# Fork to background
$0 backend start

# Control the forked backend
$0 backend {restart|stop|status}

# Run in foreground
$0 backend -f
EOF

has _daemon => sub {
  my $self = shift;
  my $program = File::Spec->catfile($self->app->home, qw( script convos-backend ));

  return Daemon::Control->new(
    fork        => 2,
    init_config => $ENV{CONVOS_INIT_CONFIG_FILE} || '/etc/default/convos',
    init_code   => "export MOJO_MODE='$ENV{MOJO_MODE}';",
    help        => $self->usage,
    name        => 'Convos backend',
    lsb_desc    => $self->description,
    lsb_sdesc   => 'Convos backend',

    directory    => $self->app->home,
    program      => -x $program ? $program : 'convos-backend',
    program_args => ['-f'],
    pid_file     => $ENV{CONVOS_BACKEND_PID_FILE} || File::Spec->catfile(File::Spec->tmpdir, 'convos-backend.pid'),
    stderr_file => $ENV{CONVOS_BACKEND_LOGFILE} || File::Spec->devnull,
    stdout_file => $ENV{CONVOS_BACKEND_LOGFILE} || File::Spec->devnull,

    user  => $ENV{RUN_AS_USER},
    group => $ENV{RUN_AS_GROUP},
  );
};

=head1 METHODS

=head2 run

Will start the backend.

=cut

sub run {
  my ($self, @args) = @_;
  my $daemon = $self->_daemon;

  $daemon->read_pid;

  if (!@args or $args[0] ne '-f') {
    local $ENV{CONVOS_IS_CONTROLLED_BY_DC} = 1;
    $self->_exit($daemon->run_command(@args));
  }
  if (!$ENV{CONVOS_IS_CONTROLLED_BY_DC} and $daemon->pid and $daemon->pid_running) {
    $self->app->log->warn('Backend is already running.');
    return 0;
  }

  $daemon->pid($$);
  $daemon->write_pid;
  $self->{running} = 1;
  $self->app->log->info('Starting convos backend.');
  $self->app->core->start;
  Mojo::IOLoop->start unless $ENV{CONVOS_BACKEND_EMBEDDED};
}

sub DESTROY {
  my $self = shift;
  return unless $self->_daemon;
  my $file = $self->_daemon->pid_file;

  unlink $file if $self->{running} and -w $file;
}

sub _exit {
  exit $_[1];
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
