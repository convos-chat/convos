package Convos::Control::Frontend;

=head1 NAME

Convos::Control::Frontend - Extends Daemon::Control to control Convos frontend

=head1 DESCRIPTION

L<Convos::Control::Frontend> is a sub class of L<Daemon::Control> used to
control L<hypnotoad|Mojo:Server::Hypnotoad>.

=head1 SYNOPSIS

  use Convos::Control::Frontend;
  exit Convos::Control::Frontend->new->run;

=cut

use Mojo::Base 'Daemon::Control';
use File::Spec;

=head1 ATTRIBUTES

=head2 directory

Defaults to L<Convos home|Mojo::Home>.

=head2 init_code

Code to be injected into the init script.

=head2 init_config

File to source environment variables for init script. Default to
"/etc/default/convos".

=head2 lsb_desc

"Start Convos frontend with hypnotoad".

=head2 lsb_sdesc

"Convos frontend".

=head2 name

"Convos frontend".

=head2 pid_file

Default to C<CONVOS_FRONTEND_PID_FILE> environment variable.

=head2 program_args

Array ref with one argument: The full path to C<convos> executable.

=head2 program

"hypnotoad".

=head2 reload_signal

"USR2".

=cut

has directory => sub {
  local $ENV{MOJO_LOG_LEVEL} = 'warn';
  require Convos;
  return Convos->home;
};

has init_code => sub {"export MOJO_MODE='$ENV{MOJO_MODE}';"};
has init_config => sub { $ENV{CONVOS_INIT_CONFIG_FILE} || '/etc/default/convos' };
has lsb_desc     => 'Start Convos frontend with hypnotoad';
has lsb_sdesc    => 'Convos frontend';
has name         => 'Convos frontend';
has pid_file     => sub { $ENV{CONVOS_FRONTEND_PID_FILE} };
has program_args => sub { [File::Spec->catfile($FindBin::Bin, 'convos')] };
has program      => 'hypnotoad';
has reload_signal => sub {'Required in constructor'};

=head1 METHODS

=head2 do_help

Will print help to screen.

=cut

sub do_help {
  print "Usage: convos frontend {start|stop|reload|restart|foreground|status|get_init_file}\n";
  return 0;
}

=head2 do_start

Will start hypnotoad in background or foreground mode.

=cut

sub do_start {
  my $self = shift;

  # already running
  if ($self->read_pid and $self->pid and $self->pid_running) {
    $self->pretty_print('Already running', 'red');
    return 1;
  }

  # foreground
  if (!$self->fork) {
    system $self->program, -f => @{$self->program_args};
    return $?;
  }

  # background
  $ENV{CONVOS_FRONTEND_LOGFILE} ||= File::Spec->devnull;
  system $self->program, @{$self->program_args};
  $self->pretty_print($? ? ('Failed to start', 'red') : 'Started');
  return $?;
}

=head2 new

Object constructor.

=cut

# This is required, since Daemon::Control::new() sets the defaults
sub new {
  my $self = shift->SUPER::new(@_);
  $self->reload_signal('USR2');
  $self->fork(2) unless defined $self->fork;
  $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
