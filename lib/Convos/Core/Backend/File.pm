package Convos::Core::Backend::File;

=head1 NAME

Convos::Core::Backend::File - Backend for storing object to file

=head1 DESCRIPTION

L<Convos::Core::Backend::File> contains methods which is useful for objects
that want to be persisted to disk or store state to disk.

=head2 Where is data stored

C<CONVOS_HOME> can be set to specify the root location for where to save
data from objects. The default directory on *nix systems is something like this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=head2 Directory structure

  $CONVOS_HOME/
  $CONVOS_HOME/joe@example.com/                                 # one directory per user
  $CONVOS_HOME/joe@example.com/settings.json                    # user settings
  $CONVOS_HOME/joe@example.com/irc/freenode/settings.json       # connection settings
  $CONVOS_HOME/joe@example.com/irc/freenode/2015/02.log         # connection log
  $CONVOS_HOME/joe@example.com/irc/freenode/2015/10/marcus.log  # conversation log
  $CONVOS_HOME/joe@example.com/irc/freenode/2015/12/#convos.log # conversation log

Notes about the structure:

=over 4

=item * Easy to delete a user and all associated data.

=item * Easy to delete a connection and all associated data.

=item * One log file per month should not cause too big files.

=item * Hard to delete a conversation thread. Ex: all conversations with "marcus".

=item * Hard to search for messages between connections for a given date.

=back

=cut

use Mojo::Base 'Convos::Core::Backend';
use Mojo::Home;
use Mojo::IOLoop::ForkCall ();
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

=head2 delete_object

See L<Convos::Core::Backend/delete_object>.

=cut

sub delete_object {
  my ($self, $obj, $cb) = @_;
  my $method = $obj->isa('Convos::Core::User') ? '_delete_user' : '_delete_connection';

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      my $fc = $delay->data->{fc} = Mojo::IOLoop::ForkCall->new;
      $fc->run(sub { $self->$method($obj) }, $delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      warn "[@{[ref $obj]}] Delete object: @{[$err || 'Success']}\n" if DEBUG;
      $self->$cb($err || '');
    },
  );

  return $self;
}

=head2 find_connections

See L<Convos::Core::Backend/find_connections>.

=cut

sub find_connections {
  my ($self, $user, $cb) = @_;
  my $user_dir = $self->home->rel_dir($user->email);
  my ($PROTOCOLS, @names);

  unless (opendir $PROTOCOLS, $user_dir) {
    Mojo::IOLoop->next_tick(sub { $self->$cb($!, \@names) });
    return $self;
  }

  for my $protocol (grep {/^\w/} readdir $PROTOCOLS) {
    opendir(my $CONNECTIONS, catdir $user_dir, $protocol) or next;
    for my $name (grep {/^\w/} readdir $CONNECTIONS) {
      push @names, [$protocol, $name] if -e catfile $user_dir, $protocol, $name, 'settings.json';
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
  return $self->tap($cb, '', [grep { /.\@./ and -r $home->rel_file("$_/settings.json") } grep {/^\w/} readdir $DH]);
}

=head2 load_object

See L<Convos::Core::Backend/load_object>.

=cut

sub load_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);
  my $settings     = {};

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($storage_file));
    $obj->INFLATE($settings);
    warn "[@{[ref $obj]}] Load success. ($storage_file)\n" if DEBUG;
    Mojo::IOLoop->next_tick(sub { $obj->$cb('') });
    1;
  } or do {
    my $err = $@;
    warn "[@{[ref $obj]}] Load $err ($storage_file)\n" if DEBUG;
    Mojo::IOLoop->next_tick(sub { $obj->$cb($err) });
  };

  return $self;
}

=head2 messages

See L<Convos::Core::Backend/messages>.

=cut

sub messages {
  my ($self, $obj, $query, $cb) = @_;
  my $level = $query->{level} || 'info|warn|error';
  my $limit = $query->{limit} || 60;
  my $re    = $query->{match} || qr{.};
  my $found = 0;
  my ($after, $before);

  $after  = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{after})  if $query->{after};
  $before = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{before}) if $query->{before};
  $before = gmtime if !$before and !$after;
  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) \[($level)\] (.*$re.*)$/;

  # TODO:
  # Need to implement logic for searching in multiple files since the _log()
  # method "rotate" files every month.
  # The search should probably be done in a fork, using Mojo::IOLoop::ForkCall.
  # We might want to add a requirement for both "before" and "after" to be set,
  # so this method doesn't run forever.
  $self->$cb('', []);    # TODO
  return $self;

  local $! = 0;
  open my $FH, '/some/log/file' or return $self->$cb($!, undef);

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

    last if ++$found == $limit;
  }

  $self->$cb($!, []);
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
    Mojo::IOLoop->next_tick(sub { $obj->$cb('') });
    1;
  } or do {
    my $err = $@;
    warn "[@{[ref $obj]}] Save $err ($storage_file)\n" if DEBUG;
    Mojo::IOLoop->next_tick(sub { $obj->$cb($err) });
  };

  return $self;
}

sub _build_home {
  my $self = shift;
  my $home = shift || $ENV{CONVOS_HOME};

  if (!$home) {
    $home = File::HomeDir->my_home;
    $home = catdir($home, qw( .local share convos )) if $home;
  }
  if ($home) {
    $home = Cwd::abs_path($home) || $home;
  }

  die 'Could not figure out CONVOS_HOME. $HOME directory could not be found.' unless $home;
  warn "[Convos::Core] Home is $home\n" if DEBUG;
  Mojo::Home->new($home);
}

sub _delete_connection {
  my ($self, $connection) = @_;
  my $path = $self->home->rel_dir(join('/', $connection->user->email, $connection->protocol, $connection->name));
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _delete_user {
  my ($self, $user) = @_;
  my $path = $self->home->rel_dir($user->user->email);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _log {
  my ($self, $obj, $level, $message) = @_;
  my $t  = gmtime;
  my $ym = sprintf '%s/%02s', $t->year, $t->mon;
  my $FH = $self->{log_fh}{$obj}{$ym};

  unless ($FH) {
    my @path = ($obj->user->email);
    push @path, map { ($_->protocol, $_->name) } $obj->isa('Convos::Core::Connection') ? $obj : $obj->connection;
    push @path, $ym;
    push @path, $obj->name if $obj->isa('Convos::Core::Conversation');
    my $path = $self->home->rel_file(join('/', @path) . '.log');
    File::Path::make_path(File::Basename::dirname($path));
    open $FH, '>>', $path or die "Can't open log file $path: $!";
    $self->{log_fh}{$obj}{$ym} = $FH;
    delete $self->{log_fh}{$obj};    # make sure we remove old file handles
  }

  flock $FH, LOCK_EX;
  printf {$FH} sprintf "%s [%s] %s\n", $t->datetime, $level, $message;
  flock $FH, LOCK_UN;
}

sub _settings_file {
  my ($self, $obj) = @_;

  return $obj->isa('Convos::Core::Connection')
    ? $self->home->rel_file(sprintf '%s/%s/%s/settings.json', $obj->user->email, $obj->protocol, $obj->name)
    : return $self->home->rel_file(sprintf '%s/settings.json', $obj->email);
}

sub _setup {
  my $self = shift;

  $self->home($self->_build_home($self->{home})) unless ref $self->{home};

  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      Scalar::Util::weaken($self);
      $connection->on(log => sub { $self->_log(@_) });
    }
  );

  $self->on(
    conversation => sub {
      my ($self, $conversation) = @_;
      Scalar::Util::weaken($self);
      $conversation->on(log => sub { $self->_log(@_) });
    }
  );
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
