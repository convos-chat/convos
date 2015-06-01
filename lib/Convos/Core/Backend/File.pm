package Convos::Core::Backend::File;

=head1 NAME

Convos::Core::Backend::File - Backend for storing object to file

=head1 DESCRIPTION

L<Convos::Core::Backend::File> contains methods which is useful for objects
that want to be persisted to disk or store state to disk.

=head2 Where data is stored

C<CONVOS_HOME> can be set to specify the root location for where to save
data from objects. The default directory on *nix systems is something like this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=head2 Directory structure

  $CONVOS_HOME/
  $CONVOS_HOME/joe@example.com/                       # one directory per user
  $CONVOS_HOME/joe@example.com/settings.json          # this works, since a connection can only have [\w_-]+
  $CONVOS_HOME/joe@example.com/freenode/              # one directory per connection
  $CONVOS_HOME/joe@example.com/freenode/settings.json # this works, since a log file ends on .log and not .json
  $CONVOS_HOME/joe@example.com/freenode/marcus.log    # private conversation log file
  $CONVOS_HOME/joe@example.com/freenode/#convos.log   # channel conversation log file
  $CONVOS_HOME/joe@example.com/freenode.log           # server log file

=cut

use Mojo::Base 'Convos::Core::Backend';
use Mojo::Home;
use Mojo::JSON;
use Cwd ();
use Fcntl ':flock';
use File::HomeDir ();
use File::Path    ();
use File::Spec::Functions qw( catdir catfile );
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

=head1 ATTRIBUTES

L<Convos::Core::Backend::File> inherits all attributes from
L<Convos::Core::Backend> and implements the following new ones.

=head2 home

Holds a L<Mojo::Home> object which points to the root directory where data
can be stored.

=cut

has home => sub { shift->_build_home };

=head1 METHODS

L<Convos::Core::Backend::File> inherits all methods from
L<Convos::Core::Backend> and implements the following new ones.

=head2 find_connections

See L<Convos::Core::Backend/find_connections>.

=cut

sub find_connections {
  my ($self, $user, $cb) = @_;
  my $base = $self->home->rel_dir($user->email);

  return $self->tap($cb, $!, []) unless opendir(my $DH, $base);
  return $self->tap($cb, '',
    [map { [split /-/, $_, 2] } grep { /^\w+-[\w-]+$/ and -r catfile($base, $_, 'settings.json') } readdir $DH]);
}

=head2 find_users

See L<Convos::Core::Backend/find_users>.

=cut

sub find_users {
  my ($self, $cb) = @_;
  my $home = $self->home;

  return $self->tap($cb, $!, []) unless opendir(my $DH, $home);
  return $self->tap($cb, '', [grep { /.\@./ and -r $home->rel_file("$_/settings.json") } readdir $DH]);
}

=head2 load_object

See L<Convos::Core::Backend/load_object>.

=cut

sub load_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);
  my $settings     = {};

  $cb ||= sub { die $_[1] if $_[1] };

  if (-e $storage_file) {
    eval {
      $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($storage_file));
      $obj->{$_} = $settings->{$_} for keys %$settings;
      warn "[@{[ref $obj]}] Load success. ($storage_file)\n" if DEBUG;
      1;
    } or do {
      warn "[@{[ref $obj]}] Load $@ ($storage_file)\n" if DEBUG;
      $obj->$cb($@);
    };
  }

  $obj->$cb('');
  $self;
}

=head2 save_object

See L<Convos::Core::Backend/save_object>.

=cut

sub save_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    my $dir = File::Basename::dirname($storage_file);
    File::Path::make_path($dir) unless -d $dir;
    Mojo::Util::spurt(Mojo::JSON::encode_json($obj->TO_JSON('private')), $storage_file);
    warn "[@{[ref $obj]}] Save success. ($storage_file)\n" if DEBUG;
    $obj->$cb('');
    1;
  } or do {
    warn "[@{[ref $obj]}] Save $@ ($storage_file)\n" if DEBUG;
    $obj->$cb($@);
  };

  $self;
}

sub _build_home {
  my $self = shift;
  my $path = shift || $ENV{CONVOS_HOME};

  unless ($path) {
    my $home = File::HomeDir->my_home || die 'Could not figure out CONVOS_HOME. $HOME directory could not be found.';
    $path = catdir($home, qw( .local share convos ));
  }

  warn "[Convos::Core] Home is $path\n" if DEBUG;
  Mojo::Home->new(Cwd::abs_path($path));
}

sub _format_log_message {
  my ($self, $level, $message) = @_;
  my ($s, $m, $h, $day, $month, $year) = gmtime;
  sprintf "%04d-%02d-%02dT%02d:%02d:%02d [%s] %s\n", $year + 1900, $month + 1, $day, $h, $m, $s, $level, $message;
}

sub _log {
  my $self = shift;
  my $fh   = $self->_log_fh(shift);    # $obj

  flock $fh, LOCK_EX;
  printf {$fh} $self->_format_log_message(@_);    # ($level, $message)
  flock $fh, LOCK_UN;
}

# TODO: Add global caching of filehandle so we can have a pool
# of filehandles. Maybe something like FileCache.pm?
sub _log_fh {
  return $_[0]->{_log_fh} if $_[0]->{_log_fh};
  my ($self, $obj) = @_;
  my $path = $self->home->rel_file($obj->_path . '.log');
  File::Path::make_path(File::Basename::dirname($obj->_path));
  open my $fh, '>>', $path or die "Could not open log file $path: $!";
  $obj->{_log_fh} = $fh;
}

sub _setup {
  my $self = shift;

  $self->home($self->_build_home($self->home)) unless ref $self->home;

  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      $connection->on(log => sub { $self->_log(@_) });
    }
  );

  $self->on(
    room => sub {
      my ($self, $room) = @_;
      $room->on(log => sub { $self->_log(@_) });
    }
  );
}

sub _settings_file {
  my ($self, $obj) = @_;
  $self->home->rel_file(join '/', $obj->_path, 'settings.json');
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
