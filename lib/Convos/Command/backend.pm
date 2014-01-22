package Convos::Command::backend;

=head1 NAME

Convos::Command::backend - Start convos backend

=head1 DESCRIPTION

This convos command will start the convos backend in a standalone process.
At the same time a lock file is created preventing a frontend from starting
the backend.

=cut

use Mojo::Base 'Mojolicious::Command';

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Start the Convos IRC proxy.\n";
has usage       => <<"EOF";
Usage: $0 backend
EOF

=head1 METHODS

=head2 run

Will start the backend.

=cut

sub run {
  my ($self, @args) = @_;
  my $app   = $self->app;
  my $loop  = Mojo::IOLoop->singleton;
  my $redis = $app->redis;

  unless ($ENV{MOJO_MODE}) {
    die qq(MOJO_MODE need to be set to either "production" or "development".\n);
  }

  $SIG{QUIT} = sub {
    $app->log->info('Gracefully stopping backend...');
    $loop->max_connnections(0);
    $redis->del('convos:backend:pid') if $redis;
  };

  $ENV{CONVOS_BACKEND_EMBEDDED} = 1;
  $redis->set('convos:backend:pid', $$);
  $redis->expire('convos:backend:lock' => 1);
  $app->core->start;
  $app->log->info('Starting convos backend');
  $loop->start;
  return 0;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
