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

=head1 METHODS

=head2 run

This method creates a lock file which prevent a frontend from also starting
the backend. Will then call L<WebIrc::Core/start> and L<WebIrc::Proxy/start>.
The proxy will only be started if enabled in the config file.

=cut

sub run {
  my($self, @args) = @_;
  my $app = $self->app;

  if(++$ENV{WIRC_BACKEND_REV} == 1 and !$app->_start_backend) {
    die "Backend is already started\n";
  }
  if($ENV{WIRC_BACKEND_REV} == 1) {
    my $lock_file = $self->app->config->{backend}{lock_file};
    $app->log->debug("Backend lock_file: $lock_file");
  }

  $self->{foreground} = int grep { $_ eq '-f' } @args;
  $self->_lock->_exec;
  $app->core->start;
  $app->proxy->start if $app->config->{backend}{proxy};
  Mojo::IOLoop->start;
  $app->log->warn('Mojo::IOLoop completed');
  $self->_term;
  return 0;
}

sub _exec {
  my $self = shift;

  unless($self->{foreground}) {
    die "Can't fork: $!" unless defined(my $pid = fork);
    $pid and _exit('Backend running in background');
    open STDIN, '</dev/null';
    open STDOUT, '>/dev/null';
    open STDERR, '>&STDOUT';
  }

  $ENV{MOJO_MODE} and return $self;
  $ENV{MOJO_MODE} = 'production';
  warn "exec($0 @ARGV)\n" if $ENV{WIRC_DEBUG};
  exec $0 => @ARGV;
}

sub _lock {
  my $self = shift;
  my $lock_file = $self->app->config->{backend}{lock_file};

  $SIG{INT} = $SIG{TERM} = sub { $self->_term; exit 0 };

  open my $LOCK, '>', $lock_file or die "Create $lock_file: $!";
  print $LOCK $$;
  close $LOCK;
  $self;
}

sub _term {
  my $self = shift;
  my $lock_file = $self->app->config->{backend}{lock_file};

  if(-e $lock_file) {
    $self->app->log->debug('Cleaning up on signal.');
    unlink $lock_file;
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
