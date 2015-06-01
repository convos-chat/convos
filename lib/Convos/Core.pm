package Convos::Core;

=head1 NAME

Convos::Core - Convos Models

=head1 DESCRIPTION

L<Convos::Core> is a class which is used to instantiate other core objects
with proper defaults.

=head1 SYNOPSIS

  use Convos::Core;
  my $core = Convos::Core->new;
  my $user = $core->user($email);

=head1 SEE ALSO

=over 4

=item * L<Convos::Core::User>

=back

=cut

use Mojo::Base -base;
use Cwd           ();
use File::HomeDir ();
use File::Spec;
use Role::Tiny::With;
use constant CONNECT_TIMER => $ENV{CONVOS_CONNECT_TIMER} || 3;
use constant DEBUG         => $ENV{CONVOS_DEBUG}         || 0;

with 'Convos::Core::Role::ClassFor';

=head1 ATTRIBUTES

L<Convos::Core> inherits all attributes from L<Mojo::Base> and implements
the following new ones.

=head1 METHODS

L<Convos::Core> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 new_with_backend

  $self = Convos::Core->new_with_backend($backend => %attrs);
  $self = Convos::Core->new_with_backend($backend => \%attrs);

Will create a new object with a given C<$backend>. Supported backends are
currently:

=over 4

=item * L<Convos::Core::Role::File>

=item * L<Convos::Core::Role::Memory>

=back

=cut

sub new_with_backend {
  my ($class, $backend) = (shift, shift);
  $backend = "Convos::Core::Role::$backend" unless $backend =~ /::/;
  warn "[Convos::Core] Will use backend $backend\n" if DEBUG;
  Role::Tiny->create_class_with_roles($class, $backend)->new(@_);
}

=head2 start

  $self = $self->start;

Will start the backend. This means finding any users and start known
connections.

=cut

sub start {
  my $self  = shift;
  my $delay = Mojo::IOLoop->delay;
  my @steps;

  Scalar::Util::weaken($self);

  # 0. get all users
  push @steps, sub { $self and $self->_find_users(shift->begin) };

  # 1. get connections for a user
  push @steps, sub {
    my ($delay, $err, $users) = @_;
    $delay->data(users => $users) if $users;
    $users ||= $delay->data('users') || [];    # required when called from connect/delay step
    return $delay->remaining([@steps[3, 0, 1, 2]])->pass unless my $user = shift @$users;    # start over after delay
    return $user->_find_connections($delay->begin);                                          # connect to connections
  };

  # 2. connect to connections
  push @steps, sub {
    my ($delay, $err, $conns) = @_;
    return unless $self;
    return $delay->remaining([@steps[3, 1, 2]])->pass unless my $c = shift @$conns;    # get connections for next user
    $c->connect(sub { });                                                              # connect to this connection
    $delay->remaining([@steps[3, 2]])->pass('', $conns);                               # connect to next connection
  };

  # 3. delay step
  push @steps, sub { $_[0]->ioloop->timer(CONNECT_TIMER, $_[0]->begin) };

  warn "[Convos::Core] Starting backend.\n" if DEBUG;
  $delay->steps(@steps[0, 1, 2]);
  return $self;
}

=head2 user

  $user = $self->user($email);

Returns a L<Convos::Core::User> object.

=cut

sub user {
  my ($self, $email) = (shift, shift);

  die "Invalid email $email. Need to match /.\@./." unless $email and $email =~ /.\@./;
  $email = lc $email;
  $self->{users}{$email} ||= do {
    my $user = $self->_class_for('Convos::Core::User')->new(core => $self, email => $email);
    warn "[Convos::Core] New user object for email=$email\n" if DEBUG;
    Scalar::Util::weaken($user->{core});
    $user;
  };
}

sub _build_home {
  my $self = shift;
  my $path = $ENV{CONVOS_SHARE_DIR};

  unless ($path) {
    my $home = File::HomeDir->my_home
      || die 'Could not figure out CONVOS_SHARE_DIR. $HOME directory could not be found.';
    $path = File::Spec->catdir($home, qw( .local share convos ));
  }

  warn "[Convos::Core] Home is $path\n" if DEBUG;
  Mojo::Home->new(Cwd::abs_path($path));
}

sub _compose_classes_with { }
sub _setting_keys         { }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
