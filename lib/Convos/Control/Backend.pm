package Convos::Control::Backend;

=head1 NAME

Convos::Control::Backend - Extends Daemon::Control to control Convos backend

=head1 DESCRIPTION

L<Convos::Control::Backend> is a sub class of L<Convos::Control> used to
control the backend

=head1 SYNOPSIS

  use Convos::Control::Backend;
  exit Convos::Control::Backend->new->run;

=cut

use Mojo::Base 'Convos::Control';

=head1 ATTRIBUTES

=head2 group

Default to C<RUN_AS_GROUP> environment variable or the first group of
L</user>.

=head2 lsb_desc

"Start Convos backend".

=head2 lsb_sdesc

"Convos backend".

=head2 name

"Convos backend".

=head2 program

Returns a callback which can be used to start the backend.

=head2 pid_file

Default to C<CONVOS_BACKEND_PID_FILE> environment variable.

=head2 stderr_file

Default to C<CONVOS_BACKEND_LOGFILE> environment variable.

=head2 stdout_file

Default to C<CONVOS_BACKEND_LOGFILE> environment variable.

=head2 user

Default to C<RUN_AS_USER> environment variable or the current user.

=cut

has lsb_desc    => 'Start Convos backend';
has lsb_sdesc   => 'Convos backend';
has name        => 'Convos backend';
has program     => sub { \&_start_backend };
has pid_file    => sub { $ENV{CONVOS_BACKEND_PID_FILE} };
has stderr_file => sub { $ENV{CONVOS_BACKEND_LOGFILE} || File::Spec->devnull };
has stdout_file => sub { $ENV{CONVOS_BACKEND_LOGFILE} || File::Spec->devnull };

=head1 METHODS

=head2 new

Object constructor.

=cut

# This is required, since Daemon::Control::new() sets the defaults
sub new {
  my $self = shift->SUPER::new(@_);
  $self->reload_signal('USR2');
  $self->group($ENV{RUN_AS_GROUP}) unless defined $self->group;
  $self->user($ENV{RUN_AS_USER})   unless defined $self->user;
  $self;
}

sub _start_backend {
  local $ENV{CONVOS_BACKEND_ONLY} = 1;
  require Convos;
  my $convos = Convos->new;
  $convos->log->info('Starting convos backend.');
  $convos->core->start;
  Mojo::IOLoop->start;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
