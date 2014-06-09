package Convos::Command::version;

=head1 NAME

Convos::Command::version - Version command

=head1 DESCRIPTION

L<Convos::Command::version> shows version information for L<Convos>, installed
core and optional modules.

See also L<Mojolicious::Command::version>.

=cut

use Mojo::Base 'Mojolicious::Command::version';

has _latest_version => sub {
  eval {
    my $ua = Mojo::UserAgent->new(max_redirects => 10);
    $ua->proxy->detect;
    $ua->get('http://api.metacpan.org/v0/release/Convos')->res->json->{version};
  };
};

=head1 METHODS

=head2 run

Run this command.

=cut

sub run {
  my $self         = shift;
  my $redis        = $self->app->redis;
  my $delay        = $redis->ioloop->delay;
  my $code_version = Convos->VERSION;
  my $database_version;

  $ENV{MOJO_MODE} ||= '';

  $redis->get('convos:version', sub { $database_version = pop; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;

  print <<EOF;
Convos
  Mode     ($ENV{MOJO_MODE})
  Code     ($code_version)
  Database (@{[$database_version || 'Unknown']})

EOF

  $self->SUPER::run(@_);    # Mojolicious version information

  unless ($database_version) {
    say "You need to update your Convos database. Run '$0 upgrade' for more information.";
  }

  if ($self->_latest_version and $code_version < $self->_latest_version) {
    say "You might want to update your Convos to @{[$self->_latest_version]}.";
  }

  return 0;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
