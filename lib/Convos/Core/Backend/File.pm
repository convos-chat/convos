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
  $CONVOS_HOME/joe@example.com/                             # one directory per user
  $CONVOS_HOME/joe@example.com/user.json                    # this works, since a connection can only have [\w_-]+
  $CONVOS_HOME/joe@example.com/IRC/freenode/                # one directory per connection
  $CONVOS_HOME/joe@example.com/IRC/freenode/connection.json # this works, since a log file ends on .log and not .json
  $CONVOS_HOME/joe@example.com/IRC/freenode/marcus.log      # private conversation log file
  $CONVOS_HOME/joe@example.com/IRC/freenode/#convos.log     # channel conversation log file
  $CONVOS_HOME/joe@example.com/IRC/freenode.log             # server log file

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
  my @names;

  return $self->$cb($!, \@names) unless opendir(my $TYPES, $base);

  for my $type (grep {/^\w+$/} readdir $TYPES) {
    opendir(my $CONNECTIONS, catdir $base, $type) or next;
    for my $name (grep {/^\w+/} readdir $CONNECTIONS) {
      push @names, [$type, $name] if -r catfile($base, $type, $name, 'connection.json');
    }
  }

  return $self->tap($cb, '', \@names);
}

=head2 find_users

See L<Convos::Core::Backend/find_users>.

=cut

sub find_users {
  my ($self, $cb) = @_;
  my $home = $self->home;

  return $self->tap($cb, $!, []) unless opendir(my $DH, $home);
  return $self->tap($cb, '', [grep { /.\@./ and -r $home->rel_file("$_/user.json") } readdir $DH]);
}

=head2 load_object

See L<Convos::Core::Backend/load_object>.

=cut

sub load_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_storage_file($obj);
  my $settings     = {};

  $cb ||= sub { die $_[1] if $_[1] };

  if (-e $storage_file) {
    eval {
      $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($storage_file));
      $obj->INFLATE($settings);
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
  my $storage_file = $self->_storage_file($obj);

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

sub _log {
  my ($self, $obj, $level, $message) = @_;
  my ($s, $m, $h, $day, $month, $year) = gmtime;
  my $fh;

  $month += 1;
  $year  += 1900;
  $day   = "0$day"   if $day < 10;
  $month = "0$month" if $month < 10;
  $fh    = $self->{log}{$obj}{"$year-$month-$day"}{fh};

  unless ($fh) {
    delete $self->{log}{$obj};    # make sure we close filehandle from yesterday
    $obj->path =~ m!^(.*)/(.+)$! or die "Invalid path() from $obj";    # path() return unix style /dir/file
    my $dirname = $self->home->rel_dir($1);
    my $path    = catfile($dirname,
      $obj->isa('Convos::Core::Connection') ? "$2/$year-$month-$day.log" : "$year-$month-$day-$2.log");
    File::Path::make_path($dirname);
    open $fh, '>>', $path or die "Could not open log file $path: $!";
    $self->{log_fh}{$obj}{"$year-$month-$day"} = {fh => $fh};    # TODO: Add time() so we can purge old filehandles
  }

  flock $fh, LOCK_EX;
  printf {$fh} sprintf "%d-%d-%dT%02d:%02d:%02d [%s] %s\n", $year, $month, $day, $h, $m, $s, $level, $message;
  flock $fh, LOCK_UN;
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
    conversation => sub {
      my ($self, $conversation) = @_;
      $conversation->on(log => sub { $self->_log(@_) });
    }
  );
}

sub _storage_file {
  my ($self, $obj) = @_;
  $self->home->rel_file(sprintf '%s/%s.json', $obj->path, ref($obj) =~ /::(Connection|User)/ ? lc $1 : 'settings');
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
