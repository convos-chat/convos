package Convos::Model::Role::File;

=head1 NAME

Convos::Model::Role::File - Role for storing object to file

=head1 DESCRIPTION

L<Convos::Model::Role::File> contains methods which is useful for objects
that want to be persisted to disk or store state to disk.

=head1 SYNOPSIS

  package Some::Awesome::Model;
  use Role::Tiny::With;
  with "Convos::Model::Role::File";

  # a list of accessors to persist to disk
  sub _setting_keys { qw( foo bar ) }

  1;

=head1 Where to store data

C<CONVOS_SHARE_DIR> can be set to specify the root location for where to save
data from objects. The default directory on *nix systems is something like this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=head2 Directory structure

  $CONVOS_SHARE_DIR/
  $CONVOS_SHARE_DIR/joe@example.com/                       # one directory per user
  $CONVOS_SHARE_DIR/joe@example.com/settings.json          # this works, since a connection can only have [\w_-]+
  $CONVOS_SHARE_DIR/joe@example.com/freenode/              # one directory per connection
  $CONVOS_SHARE_DIR/joe@example.com/freenode/settings.json # this works, since a log file ends on .log and not .json
  $CONVOS_SHARE_DIR/joe@example.com/freenode/marcus.log    # private conversation log file
  $CONVOS_SHARE_DIR/joe@example.com/freenode/#convos.log   # channel conversation log file
  $CONVOS_SHARE_DIR/joe@example.com/freenode.log           # server log file

=cut

use Mojo::Base -base;
use Mojo::Home;
use Mojo::JSON;
use Fcntl ':flock';
use File::Path ();
use File::Spec;
use Role::Tiny;
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

requires qw( _build_home _setting_keys );

=head1 ATTRIBUTES

=head2 home

Holds a L<Mojo::Home> object which points to where the object can store data.

=cut

has home => sub { shift->_build_home };

=head1 METHODS

=head2 load

  $self = $self->load(sub { my ($self, $err) = @_; });

Used to load settings from persistent storage. C<$err> is not set if
if C<$self> is not saved.

=cut

sub load {
  my ($self, $cb) = @_;
  my $storage_file = $self->_settings_file . '.json';
  my $settings     = {};

  $cb ||= sub { die $_[1] if $_[1] };

  if (-e $storage_file) {
    eval {
      $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($storage_file));
      $self->{$_} = $settings->{$_} for grep { defined $settings->{$_} } $self->_setting_keys;
      1;
    } or do {
      warn "[@{[ref $self]}] load: $@\n" if DEBUG;
      $self->$cb($@);
      return $self;
    };
  }

  $self->$cb('');
  $self;
}

=head2 log

  $self->log($level => $message);

This is an around method modifier, which will log the given message
to disk. The current log format is:

  $rfc_3339_datetime [$level] $message\n

Note that the C<$rfc_3339_datetime> is created from C<gmtime>, and not
C<localtime>.

=cut

around log => sub {
  my ($next, $self, $level, $format, @args) = @_;
  my $message = @args ? sprintf $format, map { $_ // '' } @args : $format;
  my $fh = $self->_log_fh;

  flock $fh, LOCK_EX;
  printf {$fh} $self->_format_log_message($level, $message);
  flock $fh, LOCK_UN;

  return $self->$next($level => $message);
};

=head2 save

  $self = $self->save(sub { my ($self, $err) = @_; });

Used to save user settings to persistent storage.

=cut

sub save {
  my ($self, $cb) = @_;
  my $storage_file = $self->_settings_file . '.json';

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    my $dir = File::Basename::dirname($storage_file);
    File::Path::make_path($dir) unless -d $dir;
    Mojo::Util::spurt(Mojo::JSON::encode_json({map { ($_, $self->{$_}) } $self->_setting_keys}), $storage_file);
    $self->$cb('');
    1;
  } or do {
    warn "[@{[ref $self]}] save: $@\n" if DEBUG;
    $self->$cb($@);
  };

  return $self;
}

around _compose_classes_with => sub { my $orig = shift; ($orig->(@_), __PACKAGE__) };

sub _find_connections {
  my ($self, $cb) = @_;    # Convos::Model::User object
  my $home = $self->home;

  return $self->tap($cb, $!, []) unless opendir(my $DH, $home);
  return $self->tap(
    $cb, '',
    [
      map { $self->connection(split /-/, $_, 2)->load }
      sort grep { /^\w+-[\w-]+$/ and -r $home->rel_file("$_/settings.json") } readdir $DH
    ]
  );
}

sub _find_users {
  my ($self, $cb) = @_;    # Convos::Model object
  my $home = $self->home;

  return $self->tap($cb, $!, []) unless opendir(my $DH, $home);
  return $self->tap($cb, '',
    [map { $self->user($_)->load } sort grep { /.\@./ and -r $home->rel_file("$_/settings.json") } readdir $DH]);
}

sub _format_log_message {
  my ($self, $level, $message) = @_;
  my ($s, $m, $h, $day, $month, $year) = gmtime;
  sprintf "%04d-%02d-%02dT%02d:%02d:%02d [%s] %s\n", $year + 1900, $month + 1, $day, $h, $m, $s, $level, $message;
}

# TODO: Add global caching of filehandle so we can have a pool
# of filehandles. Maybe something like FileCache.pm?
sub _log_fh {
  my $self = shift;
  return $self->{_log_fh} if $self->{_log_fh};
  my $path = $self->_log_file . '.log';
  open my $fh, '>>', $path or die "Could not open log file $path: $!";
  $self->{_log_fh} = $fh;
}

sub _log_file      { shift->home->to_string }
sub _settings_file { shift->home->rel_file('settings') }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
