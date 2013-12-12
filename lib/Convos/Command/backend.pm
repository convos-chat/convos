package Convos::Command::backend;

=head1 NAME

Convos::Command::backend - Start convos backend

=head1 DESCRIPTION

This convos command will start the convos backend in a standalone process.
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

has description => "Start the Convos IRC proxy.\n";
has usage => <<"EOF";
usage: $0 backend
EOF

=head1 METHODS

=head2 run

This method creates a lock file which prevent a frontend from also starting
the backend. Will then call L<Convos::Core/start> and L<Convos::Proxy/start>.
The proxy will only be started if enabled in the config file.

=cut

sub run {
  my($self, @args) = @_;
  my $app = $self->app;

  $app->core->start;
  $app->proxy->start if $app->config->{backend}{proxy};
  Mojo::IOLoop->start;
  $app->log->warn('Mojo::IOLoop completed');
  return 0;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
