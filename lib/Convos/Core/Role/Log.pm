package Convos::Core::Role::Log;

=head1 NAME

Convos::Core::Role::Log - A role for logging

=head1 DESCRIPTION

L<Convos::Core::Role::Log> is a role which provide a L</log>
method.

=head1 SYNOPSIS

  package Some::Awesome::Core;
  use Role::Tiny::With;
  with "Convos::Core::Role::Log";

  sub some_method {
    my $self = shift;
    $self->log(debug => "hi");
    $self->log(info => "logging with printf %s", "formatting");
    $self->log(warn => "oh!");
    $self->log(error => "no!");
    $self->log(fatal => "yikes!");
  }

=cut

use Mojo::Base -base;
use Role::Tiny;

=head1 METHODS

=head2 log

  $self = $self->log($level => $format, @args);

This method will emit a "log" event:

  $self->emit(log => $level => $message);

=cut

sub log {
  my ($self, $level, $format, @args) = @_;
  my $message = @args ? sprintf $format, map { $_ // '' } @args : $format;

  $self->emit(log => $level => $message);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
