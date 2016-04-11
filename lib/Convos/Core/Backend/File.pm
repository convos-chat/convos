package Convos::Core::Backend::File;
use Mojo::Base 'Convos::Core::Backend';

use Convos::Util 'DEBUG';
use Cwd ();
use Fcntl ':flock';
use File::HomeDir ();
use File::Path    ();
use File::ReadBackwards;
use File::Spec::Functions qw(catdir catfile);
use Mojo::Home;
use Mojo::IOLoop::ForkCall ();
use Mojo::JSON;
use Symbol;
use Time::Piece;
use Time::Seconds;

my %FORMAT = (
  action      => ['* %s %s',                   qw(from message)],
  kick        => ['-!- %s kicked %s. %s',      qw(kicker part message)],
  nick_change => ['-!- %s changed nick to %s', qw(nick new_nick)],
  notice      => ['-%s- %s',                   qw(from message)],
  part        => ['-!- %s parted. %s',         qw(nick message)],
  private     => ['<%s> %s',                   qw(from message)],
);

has home => sub { shift->_build_home };

has _fc => sub {
  my $fc = Mojo::IOLoop::ForkCall->new;
  $fc->on(error => sub { warn "[fc] $_[1]" });
  $fc;
};

sub connections {
  my ($self, $user, $cb) = @_;
  my $user_dir = $self->home->rel_dir($user->email);
  my ($CONNECTIONS, @connections);

  unless (opendir $CONNECTIONS, $user_dir) {
    die $! unless $cb;
    Mojo::IOLoop->next_tick(sub { $self->$cb($!, []) });
    return $self;
  }

  while (my $id = readdir $CONNECTIONS) {
    next unless $id =~ /^\w+/;
    my $settings = catfile $user_dir, $id, 'connection.json';
    next unless -e $settings;
    push @connections, Mojo::JSON::decode_json(Mojo::Util::slurp($settings));
  }

  return \@connections unless $cb;
  return $self->tap($cb, '', \@connections);
}

sub delete_object {
  my ($self, $obj, $cb) = @_;
  my $method = $obj->isa('Convos::Core::User') ? '_delete_user' : '_delete_connection';

  Mojo::IOLoop->delay(
    sub {
      $self->_fc->run(sub { $self->$method($obj) }, shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      warn "[@{[ref $obj]}] Delete object: @{[$err || 'Success']}\n" if DEBUG;
      $self->$cb($err || '');
    },
  );

  return $self;
}

sub messages {
  my ($self, $obj, $query, $cb) = @_;
  my $re = $query->{match} || qr{.};
  my %args;

  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) (.*$re.*)$/;

  $args{limit}    = $query->{limit} || 60;
  $args{messages} = [];
  $args{re}       = $re;

  # If both "before" and "after" are provided
  if ( $query->{before} && $query->{after} ) {
    $args{before} = Time::Piece->strptime($query->{before}, '%Y-%m-%dT%H:%M:%S');
    $args{after} = Time::Piece->strptime($query->{after}, '%Y-%m-%dT%H:%M:%S');
  }
  # If "before" is provided but not "after"
  # Set "after" to 12 months before "before"
  elsif ( $query->{before} && !$query->{after} ) {
    $args{before} = Time::Piece->strptime($query->{before}, '%Y-%m-%dT%H:%M:%S');
    $args{after} = $args{before}->add_months(-12);
  }
  # If "after" is provided but not "before"
  # Set "before" to 12 months after "after"
  elsif ( !$query->{before} && $query->{after} ) {
    $args{after} = Time::Piece->strptime($query->{after}, '%Y-%m-%dT%H:%M:%S');
    $args{before} = $args{after}->add_months(12);
  }
  # If neither "before" nor "after" are provided
  # Set "before" to now and "after" to 12 months before "before"
  else {
    $args{before} = gmtime;
    $args{after} = $args{before}->add_months(-12);
  }

  # Do not search if the difference between "before" and "after" is more than 12 months
  # This limits the amount of time that could be spent searching and it also prevents DoS attacks
  return $self if $args{before} - $args{after} > $args{before} - $args{before}->add_months(-12);

  # The {cursor} is used to walk through the month-hashed log files
  $args{cursor} = $args{before};

  warn "[@{[ref $obj]}] Searching $args{after} - $args{before}\n" if DEBUG;
  Mojo::IOLoop->delay(
    sub {
      $self->_fc->run(sub { $self->_messages($obj, \%args) }, shift->begin);
    },
    sub {
      my ($delay, $err, $messages) = @_;
      $self->$cb($err, $messages || []);
    },
  );

  return $self;
}

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

sub users {
  my ($self, $cb) = @_;
  my $home = $self->home;
  my @users;

  if (opendir(my $USERS, $home)) {
    while (my $email = readdir $USERS) {
      my $settings = $home->rel_file("$email/user.json");
      next unless $email =~ /.\@./ and -e $settings;    # poor mans regex
      push @users, Mojo::JSON::decode_json(Mojo::Util::slurp($settings));
    }
  }

  return \@users unless $cb;
  return $self->tap($cb, '', \@users);
}

sub _build_home {
  my $self = shift;
  my $home = shift || $ENV{CONVOS_HOME};

  if (!$home) {
    $home = File::HomeDir->my_home;
    $home = catdir($home, qw(.local share convos)) if $home;
  }
  if ($home) {
    $home = Cwd::abs_path($home) || $home;
  }

  die 'Could not figure out CONVOS_HOME. $HOME directory could not be found.' unless $home;
  warn "[Convos] Home is $home\n" if DEBUG;
  Mojo::Home->new($home);
}

sub _delete_connection {
  my ($self, $connection) = @_;
  my $path = $self->home->rel_dir(join('/', $connection->user->email, $connection->id));
  $connection->unsubscribe($_) for qw(dialog message state);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _delete_user {
  my ($self, $user) = @_;
  my $path = $self->home->rel_dir($user->user->email);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _format {
  my ($self, $key) = @_;
  my $format = $FORMAT{$key};
  return @$format if $format;
  warn "[Convos::Core::Backend::File] No format defined for $key\n" if DEBUG;
  return;
}

sub _log {
  my ($self, $obj, $ts, $message) = @_;
  my $t    = gmtime $ts;
  my $ym   = sprintf '%s/%02s', $t->year, $t->mon;
  my $file = $self->_log_file($obj, $ym);
  my $dir  = File::Basename::dirname($file);

  File::Path::make_path($dir) unless -d $dir;
  open my $FH, '>>', $file or die "Can't open log file $file: $!";
  warn "[@{[ref $obj]}] $file <<< ($message)\n" if DEBUG == 2;
  flock $FH, LOCK_EX;
  print $FH $t->datetime . " $message\n";
  flock $FH, LOCK_UN;
}

sub _log_file {
  my ($self, $obj, $t) = @_;
  my @path;

  if ($obj->isa('Convos::Core::Dialog')) {
    push @path, $obj->connection->user->id, $obj->connection->id;
  }
  elsif ($obj->isa('Convos::Core::Connection')) {
    push @path, $obj->user->id, $obj->id;
  }

  push @path, ref $t ? sprintf '%s/%02s', $t->year, $t->mon : $t;
  push @path, $obj->id if $obj->isa('Convos::Core::Dialog');

  return $self->home->rel_file(join('/', @path) . '.log');
}

# blocking method
sub _messages {
  my ($self, $obj, $args) = @_;

  return [] if $args->{after} > $args->{before};
  return $args->{messages} if $args->{cursor} < $args->{after};
  my $file = $self->_log_file($obj, $args->{cursor});
  $args->{cursor} = $args->{cursor}->add_months(-1);
  my $FH = File::ReadBackwards->new($file);

  unless ($FH) {
    warn "[@{[ref $obj]}] Read $file: $!\n" if DEBUG;
    return $self->_messages($obj, $args);
  }

  warn "[@{[ref $obj]}] Gettings messages from $file...\n" if DEBUG;
  while (my $line = $FH->getline) {
    next unless $line =~ $args->{re};
    my $message = {message => $2, ts => $1};
    my $ts = Time::Piece->strptime($message->{ts}, '%Y-%m-%dT%H:%M:%S');
    next if $ts < $args->{after} || $ts > $args->{before};
    if ($message->{message} =~ s/^<([^\s\>]+)>\s//) {
      @$message{qw(type from)} = (private => $1);
    }
    elsif ($message->{message} =~ s/^-([^\s\>]+)-\s//) {
      @$message{qw(type from)} = (notice => $1);
    }
    elsif ($message->{message} =~ s/^\* (\S+)\s//) {
      @$message{qw(type from)} = (action => $1);
    }
    elsif ($message->{message} =~ s/^(?:-!-\s)?//) {
      @$message{qw(type from)} = (server => '');
    }

    unshift @{$args->{messages}}, $message;
    return $args->{messages} if int @{$args->{messages}} == $args->{limit};
  }

  return $self->_messages($obj, $args);
}

sub _settings_file {
  my ($self, $obj) = @_;

  return $obj->isa('Convos::Core::Connection')
    ? $self->home->rel_file(sprintf '%s/%s/connection.json', $obj->user->email, $obj->id)
    : return $self->home->rel_file(sprintf '%s/user.json', $obj->email);
}

sub _setup {
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->home($self->_build_home($self->{home})) unless ref $self->{home};
  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      my $cid = $connection->id;
      my $uid = $connection->user->id;

      Scalar::Util::weaken($self);
      $connection->on(
        me => sub {
          my ($connection, $info) = @_;
          $self->emit("user:$uid", me => $info);
        }
      );
      $connection->on(
        message => sub {
          my ($connection, $target, $msg) = @_;
          my ($format, @keys) = $self->_format($msg->{type}) or return;
          my @dialog_id = $target->id eq $cid ? () : (dialog_id => $target->id);
          $self->_log($target, $msg->{ts}, sprintf $format, map { $msg->{$_} } @keys);
          $self->emit("user:$uid", message => {connection_id => $cid, @dialog_id, %$msg});
        }
      );
      $connection->on(
        state => sub {
          my ($connection, $state, $message) = @_;
          $self->_log($connection, time, sprintf '-!- %s. %s', ucfirst $state, $message);
          $self->emit("user:$uid",
            state => {connection_id => $cid, message => $message, state => $state});
        }
      );
      $connection->on(
        dialog => sub {
          my ($connection, $target, $data) = @_;
          $self->emit("user:$uid",
            dialog => {connection_id => $cid, dialog_id => $target->id, %$data});
          my ($format, @keys) = $self->_format($data->{type}) or return;
          $self->_log($connection, time, sprintf $format, map { $data->{$_} } @keys);
        }
      );
    }
  );
}

1;

=encoding utf8

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
  $CONVOS_HOME/joe@example.com/user.json                        # user settings
  $CONVOS_HOME/joe@example.com/irc-freenode/connection.json     # connection settings
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/02.log         # connection log
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/10/marcus.log  # dialog log
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/12/#convos.log # dialog log

Notes about the structure:

=over 2

=item * Easy to delete a user and all associated data.

=item * Easy to delete a connection and all associated data.

=item * One log file per month should not cause too big files.

=item * Hard to delete a dialog thread. Ex: all dialogs with "marcus".

=item * Hard to search for messages between connections for a given date.

=back

=head1 ATTRIBUTES

L<Convos::Core::Backend::File> inherits all attributes from
L<Convos::Core::Backend> and implements the following new ones.

=head2 home

Holds a L<Mojo::Home> object which points to the root directory where data
can be stored.

=head1 METHODS

L<Convos::Core::Backend::File> inherits all methods from
L<Convos::Core::Backend> and implements the following new ones.

=head2 connections

See L<Convos::Core::Backend/connections>.

=head2 delete_object

See L<Convos::Core::Backend/delete_object>.

=head2 messages

See L<Convos::Core::Backend/messages>.

=head2 save_object

See L<Convos::Core::Backend/save_object>.

=head2 users

See L<Convos::Core::Backend/users>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
