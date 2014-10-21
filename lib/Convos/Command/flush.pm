package Convos::Command::flush;

=head1 NAME

Convos::Command::flush - Flush redis database

=head1 DESCRIPTION

TODO

=cut

use Mojo::Base 'Mojolicious::Command';
use Mojo::Log;

$ENV{MOJO_MODE}      ||= 'production';
$ENV{MOJO_LOG_LEVEL} ||= 'info';

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Flush redis database.\n";
has usage       => <<"EOF";
Usage: $0 <days-to-keep>
EOF

=head1 METHODS

=head2 run

Will start the backend.

=cut

sub run {
  my ($self, $days_to_keep) = @_;
  my $app = $self->app;

  $app->log->info("Running with MOJO_MODE=$ENV{MOJO_MODE}");
  $days_to_keep or die $self->usage;

  my $remove_before = time - 86400 * $days_to_keep;
  my $human         = localtime $remove_before;
  my $redis         = $app->redis;
  my ($flush, @keys);

  $flush = sub {
    my $redis = shift;
    my $key = shift @keys or return $redis->ioloop->stop;

    local $| = 1;
    print '.';
    $redis->zremrangebyscore($key => "-inf", "($remove_before", $flush);
  };

  $redis->execute(
    'keys',
    'user:*:connection:*:msg',
    sub {
      my ($redis, $keys) = @_;
      @keys = @$keys;
      $app->log->info("Will flush @{[int @keys]} conversations...");
      $redis->$flush;
    },
  );

  $app->log->info("Will flush conversation log before $human");
  $app->log->info("Getting list of conversations...");
  $redis->ioloop->start;
  print "\n";
  $app->log->info("Conversation log before $human was flushed");
}

=head1 AUTHOR

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
