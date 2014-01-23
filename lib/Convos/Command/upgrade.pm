package Convos::Command::upgrade;

=head1 NAME

Convos::Command::upgrade - Upgrade the backend

=head1 DESCRIPTION

This command will stop any running backend and then upgrade the database.

IMPORTANT! PLEASE! DO TAKE BACKUP BEFORE RUNNING THE UPGRADE!

The upgrade process is tested, but you never know - and there is no
downgrade script.

=cut

use Mojo::Base 'Mojolicious::Command';
use Convos::Upgrader;

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Upgrade the Convos database.\n";

has usage => <<"EOF";

This command will stop any running backend and then upgrade the database.

IMPORTANT! PLEASE! DO TAKE BACKUP BEFORE RUNNING THE UPGRADE!

The upgrade process is tested, but you never know - and there is no
downgrade script.

Usage: $0 upgrade --yes
EOF

=head1 METHODS

=head2 run

Will start the upgrade process.

=cut

sub run {
  my ($self, @args) = @_;
  my $app    = $self->app;
  my $redis  = $app->redis;
  my $killed = 0;

  unless (grep { $_ eq '--yes' } @args) {
    die $self->usage;
  }
  unless ($ENV{MOJO_MODE}) {
    die qq(MOJO_MODE need to be set to either "production" or "development".\n);
  }

  $app->auto_start_backend(0);

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $redis->get('convos:backend:pid', $delay->begin);
    },
    sub {
      my ($delay, $pid) = @_;

      while ($pid) {
        $killed++;
        $app->log->warn("Killing running backend ($pid)");
        kill 'QUIT', $pid or $pid = 0;
        sleep 1;
      }

      $app->upgrader->once(finish => $delay->begin);
      $app->upgrader->run;
    },
    sub {
      my ($delay, $message) = @_;

      $app->log->info($message);
      $app->log->info("You can now start the backend again") if $killed;
    },
  )->wait;

  return 0;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
