package WebIrc::Command::backend;

=head1 NAME

WebIrc::Command::backend - Start wirc backend

=head1 DESCRIPTION

This web_irc command will start the wirc backend in a standalone process.
At the same time a lock file is created preventing a frontend from starting
the backend.

This process will detach to background unless C<-f> is sepecified after
creating the lock file.

=cut

use Mojo::Base 'Mojolicious::Command';

our @SIGNALS = qw/ HUP INT TERM /;

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Start application with HTTP and WebSocket server.\n";
has usage => <<"EOF";
usage: $0 backend
EOF

has _pid_file => sub {
  shift->app->config->{backend}{pid_file} ||= '/tmp/web_irc.pid';
};

has _pid => sub {
  open my $FH, '<', shift->_pid_file or return 0;
  my $pid = readline $FH;
  chomp $pid;
  $pid || 0;
};

=head1 METHODS

=head2 run

This method creates a lock file which prevent a frontend from also starting
the backend. Will then call L<WebIrc::Core/start> and L<WebIrc::Proxy/start>.
The proxy will only be started if enabled in the config file.

=cut

sub run {
  my($self, @args) = @_;
  my $app = $self->app;

  # used to allow fork+exec when running in background
  if(++$ENV{WIRC_BACKEND_REV} == 1) {
    $self->_create_pid_file;
    $self->_exec unless grep { $_ eq '-f' } @args;
  }

  $SIG{$_} = sub { $self->_term; exit 0 } for @SIGNALS;
  $app->core->start;
  $app->proxy->start if $app->config->{backend}{proxy};
  Mojo::IOLoop->start;
  $app->log->warn('Mojo::IOLoop completed');
  $self->_term;
  return 0;
}

sub _create_pid_file {
  my $self = shift;

  $self->app->log->debug('PID file: ' .$self->_pid_file);

  if(my $pid = $self->_pid) {
    if(kill 0, $pid) {
      die "Backend is running with PID $pid\n";
      return 0;
    }
  }

  open my $FH, '>', $self->_pid_file or die "Cannot write to PID file: $!";
  print $FH $$;
  return 1;
}

sub _exec {
  my $self = shift;

  die "Can't fork: $!" unless defined(my $pid = fork);
  $pid and _exit('Backend running in background');
  open STDIN, '</dev/null';
  open STDOUT, '>/dev/null';
  open STDERR, '>&STDOUT';
  $ENV{MOJO_MODE} ||= 'production';
  warn "exec($0 @ARGV)\n" if $ENV{WIRC_DEBUG};
  exec $0 => @ARGV;
}

sub _term {
  my $self = shift;
  my $pid_file = $self->app->config->{backend}{pid_file};

  if(-e $pid_file) {
    $self->app->log->debug('Cleaning up on signal.');
    unlink $pid_file;
  }
}

sub _exit {
    print shift, "\n";
    exit 0;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
