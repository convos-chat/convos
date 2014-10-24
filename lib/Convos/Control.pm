package Convos::Control;

=head1 NAME

Convos::Control - Base class for init scripts

=head1 DESCRIPTION

L<Convos::Control> is a base class for L<Convos::Control::Frontend>
and L<Convos::Control::Backend>.

=cut

use Mojo::Base 'Daemon::Control';
use File::Spec;

=head1 ATTRIBUTES

=head2 directory

Defaults to L<Convos home|Mojo::Home>.

=head2 init_config

File to source environment variables for init script. Default to
"/etc/default/convos".

=cut

has directory => sub {
  local $ENV{MOJO_LOG_LEVEL} = 'warn';
  require Convos;
  return Convos->new->home;
};

has init_config => sub { $ENV{CONVOS_INIT_CONFIG_FILE} || '/etc/default/convos' };

=head1 METHODS

=head2 do_env

For internal usage and debug purpose only.

Will print environment to screen.

=cut

sub do_env {
  my $self = shift;
  print "$_=$ENV{$_}\n" for sort keys %ENV;
  return 0;
}

=head2 do_help

Will print help to screen.

=cut

sub do_help {
  my $self = shift;
  my $command = ref($self) =~ /frontend/i ? 'frontend' : 'backend';
  print "Usage: convos $command {start|stop|reload|restart|foreground|status|get_init_file}\n";
  return 0;
}

=head2 run_template

Will inject C<set -a> before sourcing of L</init_config>.

=cut

sub run_template {
  my $self        = shift;
  my $out         = $self->SUPER::run_template(@_);
  my $init_config = $self->init_config;

  if ($out =~ /$init_config/) {
    $ENV{MOJO_MODE} or die "MOJO_MODE need to be set.";
    $out = "set -a;\nMOJO_MODE='$ENV{MOJO_MODE}';\n$out";
  }

  return $out;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
