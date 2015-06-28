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
use File::ReadBackwards;
use File::Spec::Functions qw( catdir catfile );
use Symbol;
use Time::Piece;
use Time::Seconds;
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

# copy/paste from File::ReadBackwards
my $MAX_READ_SIZE = 1 << 13;

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

=head2 messages

See L<Convos::Core::Backend/messages>.

=cut

sub messages {
  my ($self, $obj, $query, $cb) = @_;
  my $level = $query->{level} || 'info|warn|error';
  my $limit = $query->{limit} || 60;
  my $re    = $query->{match} || qr{.};
  my $path  = $self->home->rel_dir($obj->path) . '.log';
  my $FH    = gensym;
  my ($after, $before, $pos, @messages);

  $after  = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{after})  if $query->{after};
  $before = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{before}) if $query->{before};
  $before = gmtime if !$before and !$after;
  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) \[($level)\] (.*$re.*)$/;

  local $!;

  if ($before) {
    $pos = $self->_pos($obj, $before, 1) // 0;
    tie *$FH, 'File::ReadBackwards', $path or return $self->tap($cb, $!, \@messages);

    # this is a very ugly thing to do
    if ($pos) {
      tied(*$FH)->{read_size} = $pos % $MAX_READ_SIZE || $MAX_READ_SIZE;
      tied(*$FH)->{seek_pos} = $pos;
    }
  }
  else {
    $pos = $after ? $self->_pos($obj, $after, 0) : 0;
    open $FH, '<', $path or return $self->tap($cb, '', \@messages);
    seek $FH, $pos, 0;
  }

  warn "[@{[ref $obj]}] Messages from $path ($pos)\n" if DEBUG;

  while (<$FH>) {
    next unless /$re/;
    my $message = {timestamp => $1, level => $2, message => $3};
    if ($message->{message} =~ s/^<([^\s\>]+)>\s//) {
      @$message{qw( type sender )} = (privmsg => $1);
    }
    elsif ($message->{message} =~ s/^-([^\s\>]+)-\s//) {
      @$message{qw( type sender )} = (notice => $1);
    }
    elsif ($message->{message} =~ s/^\* (\S+)\s//) {
      @$message{qw( type sender )} = (action => $1);
    }
    elsif ($message->{message} =~ s/^(?:-!-\s)?//) {
      @$message{qw( type sender )} = (server => 'server');
    }
    push @messages, $message;
    last if @messages == $limit;
  }

  @messages = reverse @messages if $before;
  $self->$cb($!, \@messages);
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
  my $t   = gmtime;
  my $ymd = $t->ymd;
  my $FH;

  unless ($FH = $self->{log_fh}{$obj}) {
    my $path = $self->home->rel_dir($obj->path) . '.log';
    open $FH, '>>', $path or die "Append $path: $!";
    $self->{log_fh}{$obj} = $FH;
  }
  unless (defined $self->{pos}{$obj}{$ymd}) {
    my $path = $self->home->rel_dir($obj->path) . '.log.ymd';
    open my $POS, '>>', $path or die "Append $path: $!";
    printf {$POS} "%s=%s\n", $ymd, ($self->{pos}{$obj}{$ymd} = tell $FH);
  }

  flock $FH, LOCK_EX;
  printf {$FH} sprintf "%s [%s] %s\n", $t->datetime, $level, $message;
  flock $FH, LOCK_UN;
}

sub _pos {
  my ($self, $obj, $t, $before) = @_;
  my $pos = $self->{pos}{$obj};

  if (!$pos) {
    my $path = $self->home->rel_dir($obj->path) . '.log.ymd';
    if (open my $FH, '<', $path) {
      /^(.*)=(\d+)$/ and $pos->{$1} = $2 while <$FH>;
    }
  }

  return $pos->{$t->ymd} if defined $pos->{$t->ymd};

  if ($before) {
    for my $k (sort { $a cmp $b } keys %$pos) {
      my $match = Time::Piece->new($k);
      return $pos->{$k} if $match >= $t;
    }
  }
  else {
    for my $k (sort { $b cmp $a } keys %$pos) {
      my $match = Time::Piece->new($k);
      return $pos->{$k} if $match <= $t;
    }
  }

  return undef;
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
